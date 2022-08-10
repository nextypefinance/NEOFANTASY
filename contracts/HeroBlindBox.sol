// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface INFTcustom {
    function mintItem(address recipient, uint256 propertyId) external returns (uint256);
}

contract HeroBlindBox is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address[] public adminList;

    address public BASEADDRESS;

    address public platformAddress;

    /* box */
    bool public boxStatus;

    address public boxNFT;

    uint256 public boxNFTSupply;

    address public boxPayToken;

    uint256 public boxPayAmount;

    uint256 public boxStartAt;

    uint256 public boxEndAt;

    uint256 public boxRoundCurrent;

    // purchase limit list (round > limit num)
    mapping(uint256 => uint256) public boxPurchaseLimitList;

    // property id list
    uint256[] public propertyIdList;

    // property id num list
    uint256[] public propertyIdNumList;

    constructor() public {
        adminList.push(msg.sender);

        BASEADDRESS = address(1);
        platformAddress = _msgSender();

        boxStatus = false;
        boxRoundCurrent = 1;
    }

    /* admin */
    // set admin list
    function setAdminList(address[] memory _list) public nonReentrant onlyOwner {
        require(_list.length > 0, "NONEMPTY_ADDRESS_LIST");

        for (uint256 nIndex = 0; nIndex < _list.length; nIndex++) {
            require(_list[nIndex] != address(0), "ADMIN_NONEMPTY_ADDRESS");
        }
        adminList = _list;
    }

    // get admin list
    function getAdminList() public view returns (address[] memory) {
        return adminList;
    }

    function onlyAdminCheck(address _adminAddress) internal view returns (bool) {
        for (uint256 nIndex = 0; nIndex < adminList.length; nIndex++) {
            if (adminList[nIndex] == _adminAddress) {
                return true;
            }
        }
        return false;
    }

    modifier onlyAdmin() {
        require(onlyAdminCheck(msg.sender) == true, "ONLY_ADMIN_OPERATE");

        _;
    }

    /* other */
    // set platform address
    function setPlatformAddress(address _platformAddress) public nonReentrant onlyAdmin {
        require(_platformAddress != address(0), "NONEMPTY_ADDRESS");
        platformAddress = _platformAddress;
    }

    /* box */
    // set box status
    function setBoxStatus(bool _boxStatus) public nonReentrant onlyAdmin {
        boxStatus = _boxStatus;
    }

    // set box info
    function setBoxInfo(address _nft, uint256[] memory _propertyIdList, uint256[] memory _numList, address _payToken, uint256 _payAmount, uint256 _startAt, uint256 _endAt) public nonReentrant onlyAdmin {
        require((_nft != address(0)) && (_payToken != address(0)), "NONEMPTY_ADDRESS");
        require(_propertyIdList.length == _numList.length, "PROPERTY_ID_AND_NUM_MUST_EQUAL");
        for (uint256 _i = 0; _i < _propertyIdList.length; _i++) {
            require(_propertyIdList[_i] > 0, "PROPERTY_ID_ERROR");
        }
        require((_payAmount > 0), "AMOUNT_ERROR");
        require((_startAt > 0) && (_endAt > 0), "AT_ERROR");

        uint256 _supply = 0;
        for (uint256 _i = 0; _i < _numList.length; _i++) {
            _supply += _numList[_i];
        }

        boxNFT = _nft;
        propertyIdList = _propertyIdList;
        propertyIdNumList = _numList;
        boxNFTSupply = _supply;
        boxPayToken = _payToken;
        boxPayAmount = _payAmount;
        boxStartAt = _startAt;
        boxEndAt = _endAt;
    }

    // get box nft info
    function getBoxNftInfo() public view returns (uint256[] memory, uint256[] memory){
        return (propertyIdList, propertyIdNumList);
    }

    // set round current
    function setBoxRoundCurrent(uint256 _round) public nonReentrant onlyAdmin {
        require(_round > 0, "ROUND_ERROR");
        boxRoundCurrent = _round;
    }

    // set purchase limit
    function setBoxPurchaseLimitList(uint256 _round, uint256 _num) public nonReentrant onlyAdmin {
        require(_round > 0, "ROUND_ERROR");
        boxPurchaseLimitList[_round] = _num;
    }

    // get box info
    function getBoxInfo() public view returns (address, uint256, address, uint256, uint256, uint256, uint256){
        uint256 _purchaseLimit = boxPurchaseLimitList[boxRoundCurrent];
        return (boxNFT, boxNFTSupply, boxPayToken, boxPayAmount, boxStartAt, boxEndAt, _purchaseLimit);
    }

    // user purchase info (round > address > already purchase amount)
    mapping(uint256 => mapping(address => uint256)) public boxUserPurchaseInfo;

    // get user purchase amount
    function getBoxUserPurchaseAmount(address _user) public view returns (uint256){
        return boxUserPurchaseInfo[boxRoundCurrent][_user];
    }

    event BoxPurchase(address _user, address _boxNFT, uint256 _amount, address _payToken, uint256 _payAmount, uint256 _payAmountTotal, uint256[] _tokenIDList, uint256[] _propertyIdList);

    function boxPurchase(uint256 _amount) public payable nonReentrant {
        require(boxStatus == true, "PURCHASE_NOT_START");
        require(_amount > 0, "PURCHASE_AMOUNT_ERROR");
        require(boxNFTSupply >= _amount, "BOX_SELL_OUT");
        require(boxStartAt <= block.timestamp && block.timestamp <= boxEndAt, "BOX_EXPIRED");

        uint256 _userAlreadyPurchaseAmount = getBoxUserPurchaseAmount(msg.sender);
        uint256 _userAlreadyTmp = _userAlreadyPurchaseAmount.add(_amount);
        if (boxPurchaseLimitList[boxRoundCurrent] > 0) {
            require(_userAlreadyTmp <= boxPurchaseLimitList[boxRoundCurrent], "PURCHASE_LIMIT_EXCEEDED");
        }

        boxUserPurchaseInfo[boxRoundCurrent][msg.sender] = _userAlreadyTmp;

        uint256[] memory _propertyIdList = new uint256[](_amount);
        for(uint256 _dd = 0;_dd < _amount; _dd++){
            uint256 randomness_ = psuedoRandomness();
            randomness_ = randomness_.mod(boxNFTSupply);

            for(uint256 ind = 0; ind < propertyIdNumList.length; ind++){
                if(randomness_ <= propertyIdNumList[ind] && propertyIdNumList[ind] > 0){
                    _propertyIdList[_dd] = propertyIdList[ind];
                    propertyIdNumList[ind] = propertyIdNumList[ind].sub(1);
                    boxNFTSupply = boxNFTSupply.sub(1);
                    break;
                }else{
                    randomness_ = randomness_.sub(propertyIdNumList[ind]);
                }
            }
        }

        uint256 boxPayAmountTotal = boxPayAmount.mul(_amount);
        if (boxPayToken == BASEADDRESS) {
            require(msg.value == boxPayAmountTotal, "PAY_AMOUNT_ERROR");
            address payable _platformAddress = address(uint160(platformAddress));
            _platformAddress.transfer(boxPayAmountTotal);
        } else {
            IERC20(boxPayToken).safeTransferFrom(msg.sender, platformAddress, boxPayAmountTotal);
        }

        uint256[] memory _tokenIDList = new uint256[](_amount);
        for (uint256 _i = 0; _i < _amount; _i++) {
            uint256 _tokenID = INFTcustom(boxNFT).mintItem(msg.sender, _propertyIdList[_i]);
            _tokenIDList[_i] = _tokenID;
        }

        emit BoxPurchase(msg.sender, boxNFT, _amount, boxPayToken, boxPayAmount, boxPayAmountTotal, _tokenIDList, _propertyIdList);
    }

    // random
    function psuedoRandomness() public view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp + block.difficulty +
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)) +
            block.gaslimit + 
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)) +
            block.number
        )));
    }

}