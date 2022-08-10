// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract UsdtClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // order list (orderId => at)
    mapping(uint256 => uint256) public orderList;

    address[] allowedTokens;

    address[] public adminList;

    address public feeTo;

    uint256 public feeAmount;

    // token balance list (token => (user => balance))
    mapping(address => mapping(address => uint256)) private tokenBalanceList;

    constructor() public {
        adminList.push(msg.sender);
    }

    function setAdminList(address[] memory _list) public onlyOwner nonReentrant {
        require(_list.length > 0, "NONEMPTY_ADDRESS_LIST");

        for (uint256 nIndex = 0; nIndex < _list.length; nIndex++) {
            require(_list[nIndex] != address(0), "ADMIN_NONEMPTY_ADDRESS");
        }
        adminList = _list;
    }

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
    // set fee amount
    function setFeeAmount(uint256 _amount) external onlyAdmin nonReentrant {
        feeAmount = _amount;
    }

    // set fee to address
    function setfeeTo(address _address) public onlyAdmin nonReentrant {
        require(_address != address(0), "NONEMPTY_ADDRESS");
        feeTo = _address;
    }

    // get user token balance
    function getUserTokenBalance(address _token, address _user) public view returns (uint256) {
        return tokenBalanceList[_token][_user];
    }

    // check order is exist
    function checkOrderIsExist(uint256 _orderId) public view returns (bool) {
        if (orderList[_orderId] > 0) {
            return true;
        } else {
            return false;
        }
    }

    // set token token
    function setAllowedTokenList(address[] memory _tokenList) public onlyAdmin nonReentrant {
        uint256 len = _tokenList.length;
        require(len > 0, 'NONEMPTY_ADDRESS');
        for (uint256 _i = 0; _i < len; _i++) {
            require(_tokenList[_i] != address(0), "NONEMPTY_ADDRESS");
        }
        allowedTokens = _tokenList;
    }

    // add token allow
    function addAllowedTokens(address token) public onlyOwner {
        require(token != address(0), "NONEMPTY_ADDRESS");
        require(tokenIsAllowed(token) == false, "TOKEN_ALREADY_ALLOWED");

        allowedTokens.push(token);
    }

    // check token allow
    function tokenIsAllowed(address token) public view returns (bool) {
        for (uint256 _d = 0; _d < allowedTokens.length; _d++) {
            if (allowedTokens[_d] == token) {
                return true;
            }
        }
        return false;
    }

    event AddTokenBalance(address _token, address _user, uint256 _num, uint256 _orderId, uint256 _at);
    event SetTokenBalance(address _token, address _user, uint256 _num, uint256 _at);
    event AddTokenBalanceMulti(address[] _token, address[] _user, uint256[] _num, uint256[] _orderId, uint256 _at);
    event ClaimTokens(address _recipient, address _token, uint256 _amount, uint256 _at);

    function addTokenBalance(address _token, address _user, uint256 _num, uint256 _orderId) external nonReentrant onlyAdmin {
        require((_orderId > 0) && (checkOrderIsExist(_orderId) == false), "ORDER_ERROR");
        require(_token != address(0), "NONEMPTY_TOKEN");
        require(tokenIsAllowed(_token), "TOKEN_NOT_ALLOWED");
        require(_user != address(0), "NONEMPTY_ADDRESS");
        require(_num > 0, "NONEMPTY_NUM");

        orderList[_orderId] = block.timestamp;
        tokenBalanceList[_token][_user] = tokenBalanceList[_token][_user].add(_num);

        emit AddTokenBalance(_token, _user, _num, _orderId, block.timestamp);
    }

    function setTokenBalance(address _token, address _user, uint256 _num) external nonReentrant onlyAdmin {
        require(_token != address(0), "NONEMPTY_TOKEN");
        require(tokenIsAllowed(_token), "TOKEN_NOT_ALLOWED");
        require(_user != address(0), "NONEMPTY_ADDRESS");

        tokenBalanceList[_token][_user] = _num;

        emit SetTokenBalance(_token, _user, _num, block.timestamp);
    }

    function addTokenBalanceMulti(address[] calldata _tokenArr, address[] calldata _userArr, uint256[] calldata _numArr, uint256[] calldata _orderIdArr) external nonReentrant onlyAdmin {
        require(_tokenArr.length > 0, "NONEMPTY_TOKEN_LIST");
        require((_tokenArr.length == _userArr.length) && (_tokenArr.length == _numArr.length) && (_tokenArr.length == _orderIdArr.length), "INCONSISTENT_ARRAY");

        for (uint256 _dd = 0; _dd < _tokenArr.length; _dd++) {
            address _token = _tokenArr[_dd];
            address _user = _userArr[_dd];
            uint256 _num = _numArr[_dd];
            uint256 _orderId = _orderIdArr[_dd];

            require((_orderId > 0) && (checkOrderIsExist(_orderId) == false), "ORDER_ERROR");
            require(_token != address(0), "NONEMPTY_TOKEN");
            require(tokenIsAllowed(_token), "TOKEN_NOT_ALLOWED");
            require(_user != address(0), "NONEMPTY_ADDRESS");
            require(_num > 0, "NONEMPTY_NUM");

            orderList[_orderId] = block.timestamp;
            tokenBalanceList[_token][_user] = tokenBalanceList[_token][_user].add(_num);
        }

        emit AddTokenBalanceMulti(_tokenArr, _userArr, _numArr, _orderIdArr, block.timestamp);
    }

    // Claim Tokens
    function claimTokens(address _token, uint256 _amount) public payable nonReentrant {
        require(tokenIsAllowed(_token) == true, "TOKEN_NOT_ALLOWED");
        require((_amount > 0) && (_amount <= tokenBalanceList[_token][msg.sender]), "NONEMPTY_AMOUNT");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "BALANCE_INSUFFICIENT");

        tokenBalanceList[_token][msg.sender] = tokenBalanceList[_token][msg.sender].sub(_amount);

        if (feeAmount > 0) {
            require(msg.value == feeAmount, "PAY_AMOUNT_ERROR");
            address payable _feeTo = address(uint160(feeTo));
            _feeTo.transfer(feeAmount);
        }
        IERC20(_token).transfer(msg.sender, _amount);

        emit ClaimTokens(msg.sender, _token, _amount, block.timestamp);
    }
}