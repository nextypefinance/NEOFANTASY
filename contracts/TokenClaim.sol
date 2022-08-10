// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // orderId > used
    mapping(uint256 => bool) public orderList;

    address[] allowedTokens;
    address[] public adminList;

    constructor() public {
        adminList.push(msg.sender);
    }

    // token allow
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

    event ClaimTokens(address _recipient, address _token, uint256 _amount, uint256 _orderId, uint256 _at);

    // Claim Tokens
    function claimTokens(address token, uint256 amount, address recipient, uint256 orderId) public nonReentrant onlyAdmin {
        require(tokenIsAllowed(token) == true, "TOKEN_NOT_ALLOWED");
        require(amount > 0, "NONEMPTY_AMOUNT");
        require(recipient != address(0), "NONEMPTY_ADDRESS");
        require(orderList[orderId] == false, "ORDER_EXIST");
        require(IERC20(token).balanceOf(address(this)) >= amount, "BALANCE_INSUFFICIENT");

        orderList[orderId] = true;
        IERC20(token).transfer(recipient, amount);

        emit ClaimTokens(recipient, token, amount, orderId, block.timestamp);
    }

    function withdrawTokens(address token) public onlyOwner nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "BALANCE_INSUFFICIENT");

        IERC20(token).transfer(msg.sender, balance);
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
}