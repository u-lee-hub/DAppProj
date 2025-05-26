// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FortuneApp {
    // 운세 정보를 저장하는 구조체
    struct Fortune {
        string message;
        uint256 luckyNumber;
        uint256 date;
        string zodiacSign;
        bool exists;
    }
    
    // 사용자 정보를 저장하는 구조체
    struct User {
        string name;
        uint256 birthDate;
        string zodiacSign;
        bool isRegistered;
    }
    
    // 매핑: 사용자별 운세 기록 (주소 => 날짜 => 운세)
    mapping(address => mapping(uint256 => Fortune)) public userFortunes;
    
    // 매핑: 사용자 정보
    mapping(address => User) public users;
    
    // 매핑: 관리자 권한
    mapping(address => bool) public admins;
    
    // 운세 메시지 배열 (관리자가 관리)
    string[] public fortuneMessages;
    
    // 컨트랙트 소유자
    address public owner;
    
    // 이벤트 정의
    event FortuneGenerated(address indexed user, uint256 date, string message, uint256 luckyNumber);
    event UserRegistered(address indexed user, string name, string zodiacSign);
    event AdminAdded(address indexed admin);
    
    // 관리자만 실행 가능한 modifier
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Only admin can call this function");
        _;
    }
    
    // 등록된 사용자만 실행 가능한 modifier
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    // 생성자: 컨트랙트 배포자를 소유자로 설정
    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
        
        // 기본 운세 메시지 추가 (unicode 키워드 사용 <- 한글 사용 위해)
        fortuneMessages.push(unicode"오늘은 행운이 가득한 하루가 될 것입니다!");
        fortuneMessages.push(unicode"새로운 기회가 찾아올 예정입니다.");
        fortuneMessages.push(unicode"조금 더 신중하게 행동하는 것이 좋겠습니다.");
        fortuneMessages.push(unicode"사랑하는 사람과 좋은 시간을 보내세요.");
        fortuneMessages.push(unicode"금전적인 행운이 따를 것입니다.");
    }

    // ======================================================================
    // === 사용자 관련 함수 ===
    
    // 사용자 등록 함수
    function registerUser(
        string memory _name, 
        uint256 _birthDate, 
        string memory _zodiacSign
    ) public {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_zodiacSign).length > 0, "Zodiac sign cannot be empty");
        require(_birthDate > 0, "Birth date must be valid");
        
        users[msg.sender] = User({
            name: _name,
            birthDate: _birthDate,
            zodiacSign: _zodiacSign,
            isRegistered: true
        });
        
        emit UserRegistered(msg.sender, _name, _zodiacSign);
    }
    
    // 사용자 정보 조회 함수
    function getUserInfo(address _user) public view returns (
        string memory name,
        uint256 birthDate,
        string memory zodiacSign,
        bool isRegistered
    ) {
        User memory user = users[_user];
        return (user.name, user.birthDate, user.zodiacSign, user.isRegistered);
    }
    
    // 내 정보 조회 함수 (편의 함수)
    function getMyInfo() public view returns (
        string memory name,
        uint256 birthDate,
        string memory zodiacSign,
        bool isRegistered
    ) {
        return getUserInfo(msg.sender);
    }
    
    // 사용자 등록 여부 확인
    function isUserRegistered(address _user) public view returns (bool) {
        return users[_user].isRegistered;
    }

    // ======================================================================
    // === 운세 관련 함수 ===
    
    // 오늘의 운세 생성 함수
    function generateTodaysFortune() public onlyRegisteredUser returns (
        string memory message,
        uint256 luckyNumber,
        string memory zodiacSign
    ) {
        uint256 today = block.timestamp / 86400; // 하루 단위로 변환
        
        // 이미 오늘 운세를 뽑았는지 확인
        require(!userFortunes[msg.sender][today].exists, "Fortune already generated for today");
        
        // 블록해시와 사용자 주소를 이용한 랜덤 생성
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            today
        )));
        
        // 운세 메시지 선택 (랜덤)
        uint256 messageIndex = randomSeed % fortuneMessages.length;
        string memory fortuneMessage = fortuneMessages[messageIndex];
        
        // 행운의 숫자 생성 (1-100)
        uint256 luckyNum = (randomSeed % 100) + 1;
        
        // 사용자의 별자리 가져오기
        string memory userZodiac = users[msg.sender].zodiacSign;
        
        // 운세 저장
        userFortunes[msg.sender][today] = Fortune({
            message: fortuneMessage,
            luckyNumber: luckyNum,
            date: today,
            zodiacSign: userZodiac,
            exists: true
        });
        
        emit FortuneGenerated(msg.sender, today, fortuneMessage, luckyNum);
        
        return (fortuneMessage, luckyNum, userZodiac);
    }
    
    // 특정 날짜의 운세 조회
    function getFortune(uint256 _date) public view returns (
        string memory message,
        uint256 luckyNumber,
        uint256 date,
        string memory zodiacSign,
        bool exists
    ) {
        Fortune memory fortune = userFortunes[msg.sender][_date];
        return (fortune.message, fortune.luckyNumber, fortune.date, fortune.zodiacSign, fortune.exists);
    }
    
    // 오늘의 운세 조회
    function getTodaysFortune() public view returns (
        string memory message,
        uint256 luckyNumber,
        string memory zodiacSign,
        bool exists
    ) {
        uint256 today = block.timestamp / 86400;
        Fortune memory fortune = userFortunes[msg.sender][today];
        return (fortune.message, fortune.luckyNumber, fortune.zodiacSign, fortune.exists);
    }

    // ======================================================================
    // === 관리자 전용 함수 ===
    
    // 새로운 관리자 추가
    function addAdmin(address _admin) public onlyAdmin {
        require(_admin != address(0), "Invalid address");
        require(!admins[_admin], "Already an admin");
        
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }
    
    // 관리자 권한 제거
    function removeAdmin(address _admin) public onlyAdmin {
        require(_admin != owner, "Cannot remove owner");
        require(admins[_admin], "Not an admin");
        
        admins[_admin] = false;
    }
    
    // 새로운 운세 메시지 추가
    function addFortuneMessage(string memory _message) public onlyAdmin {
        require(bytes(_message).length > 0, "Message cannot be empty");
        fortuneMessages.push(_message);
    }
    
    // 운세 메시지 수정
    function updateFortuneMessage(uint256 _index, string memory _newMessage) public onlyAdmin {
        require(_index < fortuneMessages.length, "Invalid index");
        require(bytes(_newMessage).length > 0, "Message cannot be empty");
        
        fortuneMessages[_index] = _newMessage;
    }
    
    // 운세 메시지 삭제
    function removeFortuneMessage(uint256 _index) public onlyAdmin {
        require(_index < fortuneMessages.length, "Invalid index");
        require(fortuneMessages.length > 1, "Cannot remove last message");
        
        // 배열에서 요소 제거 (마지막 요소를 삭제할 인덱스로 이동)
        fortuneMessages[_index] = fortuneMessages[fortuneMessages.length - 1];
        fortuneMessages.pop();
    }
    
    // 전체 운세 메시지 개수 조회
    function getFortuneMessageCount() public view returns (uint256) {
        return fortuneMessages.length;
    }
    
    // 특정 인덱스의 운세 메시지 조회
    function getFortuneMessage(uint256 _index) public view returns (string memory) {
        require(_index < fortuneMessages.length, "Invalid index");
        return fortuneMessages[_index];
    }
    
    // 모든 운세 메시지 조회 (가스 효율성을 위해 제한적 사용)
    function getAllFortuneMessages() public view returns (string[] memory) {
        return fortuneMessages;
    }
    
    // === 유틸리티 함수 ===
    
    // 현재 날짜 (블록체인 기준) 조회
    function getCurrentDate() public view returns (uint256) {
        return block.timestamp / 86400;
    }
    
    // 컨트랙트 정보 조회
    function getContractInfo() public view returns (
        address contractOwner,
        uint256 totalFortuneMessages,
        uint256 currentDate
    ) {
        return (owner, fortuneMessages.length, getCurrentDate());
    }
}

