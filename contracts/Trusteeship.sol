// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface CustomERC721 {
    function mintItem(address recipient, uint256 propertyId) external returns (uint256);

    function burnItem(uint256 tokenId) external returns (uint256);
}

contract Trusteeship is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address[] public adminList;

    // orderId list orderId => timestamp
    mapping(uint256 => uint256) orderList;

    // fee amount
    uint256 public feeAmount;

    // mint nft fee amount
    uint256 public mintFeeAmount;

    // receive fee address
    address public feeTo;

    struct userInfo {
        address userAddress;
        bool retrievable;
    }

    // NFT token => tokenId => user info
    mapping(address => mapping(uint256 => userInfo)) public trustList;

    struct nftInfo {
        uint256[] propertyIdList;
        bool isTrust;
    }

    // user address => (nft address => nft info)
    mapping(address => mapping(address => nftInfo)) public nftList;

    constructor() public {
        adminList.push(msg.sender);
        feeTo = msg.sender;
    }

    // check order is exist
    function checkOrderIdIsExist(uint256 _orderId) public view returns (bool){
        if (orderList[_orderId] > 0) {
            return true;
        } else {
            return false;
        }
    }

    // set fee to
    function setFeeTo(address _feeTo) public nonReentrant onlyAdmin {
        require(_feeTo != address(0), "NONEMPTY_ADDRESS");
        feeTo = _feeTo;
    }

    // set fee amount
    function setFeeAmount(uint256 _feeAmount) public nonReentrant onlyAdmin {
        feeAmount = _feeAmount;
    }

    // set mint fee amount
    function setMintFeeAmount(uint256 _mintFeeAmount) public nonReentrant onlyAdmin {
        mintFeeAmount = _mintFeeAmount;
    }

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

    event AddNftBalance(address _user, address _nftToken, uint256 _propertyId, uint256 _orderID, uint256 _at);
    event BatchAddNftBalance(address _user, address _nftToken, uint256[] _propertyIdList, uint256 _orderID, uint256 _at);
    event Claim(address _user, address _nftToken, uint256[] _tokenIdList, uint256[] _propertyIdList, uint256 _at);
    event Trust(address _user, address _nftToken, uint256 _tokenId, uint256 _at);
    event BatchTrust(address _user, address _nftToken, uint256[] _tokenIds, uint256 _at);
    event RetrieveAuthorization(address _user, address _nftToken, uint256 _tokenId, uint256 _at);
    event BatchRetrieveAuthorization(address _user, address _nftToken, uint256[] _tokenIds, uint256 _at);
    event Retrieve(address _user, address _nftToken, uint256 _tokenId, uint256 _at);
    event BatchRetrieve(address _user, address _nftToken, uint256[] _tokenIds, uint256 _at);
    event BatchBurn(address _nftToken, uint256[] _tokenIdList);

    function addNftBalance(address _toAddress, address _nftToken, uint256 _propertyId, uint256 _orderID) public nonReentrant onlyAdmin {
        require(_toAddress != address(0), "NONEMPTY_USER_ADDRESS");
        require(_nftToken != address(0), "NONEMPTY_NFT_ADDRESS");
        require(_propertyId > 0, "NONEMPTY_PROPERTY_ID");
        require(_orderID > 0, "NONEMPTY_ORDER_ID");
        require(checkOrderIdIsExist(_orderID) == false, "ORDER_ID_IS_EXISTED");
        nftList[_toAddress][_nftToken].isTrust = false;

        orderList[_orderID] = block.timestamp;
        nftList[_toAddress][_nftToken].propertyIdList.push(_propertyId);
        emit AddNftBalance(_toAddress, _nftToken, _propertyId, _orderID, block.timestamp);
    }

    function batchAddNftBalance(address _toAddress, address _nftToken, uint256[] memory _propertyIdList, uint256 _orderID) public nonReentrant onlyAdmin {
        require(_toAddress != address(0), "NONEMPTY_USER_ADDRESS");
        require(_nftToken != address(0), "NONEMPTY_NFT_ADDRESS");
        require(_orderID > 0, "NONEMPTY_ORDER_ID");
        require(checkOrderIdIsExist(_orderID) == false, "ORDER_ID_IS_EXISTED");
        nftList[_toAddress][_nftToken].isTrust = false;

        orderList[_orderID] = block.timestamp;
        uint256 len = _propertyIdList.length;
        for (uint256 i = 0; i < len; i++) {
            require(_propertyIdList[i] > 0, "NONEMPTY_PROPERTY_ID");
            nftList[_toAddress][_nftToken].propertyIdList.push(_propertyIdList[i]);
        }

        emit BatchAddNftBalance(_toAddress, _nftToken, _propertyIdList, _orderID, block.timestamp);
    }

    function resetNftBalance(address _toAddress, address _nftToken, uint256[] memory _propertyIdList) public nonReentrant onlyAdmin {
        require(_toAddress != address(0), "NONEMPTY_USER_ADDRESS");
        require(_nftToken != address(0), "NONEMPTY_NFT_ADDRESS");

        nftList[_toAddress][_nftToken].propertyIdList = _propertyIdList;
    }

    function getNftBalance(address _userAddress, address _nftToken) public view returns (uint256[] memory, uint256, bool){
        require(_userAddress != address(0), "NONEMPTY_USER_ADDRESS");
        require(_nftToken != address(0), "NONEMPTY_NFT_ADDRESS");
        return (nftList[_userAddress][_nftToken].propertyIdList, nftList[_userAddress][_nftToken].propertyIdList.length, nftList[_userAddress][_nftToken].isTrust);
    }

    function claim(address _nftToken) public payable nonReentrant {
        require(_nftToken != address(0), "NONEMPTY_NFT_ADDRESS");
        require(nftList[msg.sender][_nftToken].isTrust == false, "NFT_ALREADY_RECEIVED");
        uint256[] memory _propertyIdList = nftList[msg.sender][_nftToken].propertyIdList;
        uint256 len = _propertyIdList.length;
        require(len > 0, "NO_NFT_TO_CLAIM");
        nftList[msg.sender][_nftToken].isTrust = true;
        nftList[msg.sender][_nftToken].propertyIdList = new uint256[](0);

        if (mintFeeAmount > 0 && feeTo != address(0)) {
            uint256 feeAmountTotal = mintFeeAmount.mul(len);
            require(msg.value == feeAmountTotal, "FEE_ERROR");
            address payable _feeTo = address(uint160(feeTo));
            _feeTo.transfer(feeAmountTotal);
        }

        uint256[] memory _tokenIdList = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            require(_propertyIdList[i] > 0, "NONEMPTY_PROPERTY_ID");
            uint256 _tokenId = CustomERC721(_nftToken).mintItem(address(this), _propertyIdList[i]);
            _tokenIdList[i] = _tokenId;
            trustList[_nftToken][_tokenId].userAddress = msg.sender;
        }

        emit Claim(msg.sender, _nftToken, _tokenIdList, _propertyIdList, block.timestamp);
    }

    function trust(address _nftToken, uint256 _tokenId) public nonReentrant {
        require(_nftToken != address(0), "NONEMPTY_ADDRESS");
        require((trustList[_nftToken][_tokenId].userAddress == address(0)), "TOKEN_ERROR");

        trustList[_nftToken][_tokenId].userAddress = msg.sender;
        IERC721(_nftToken).transferFrom(msg.sender, address(this), _tokenId);
        emit Trust(msg.sender, _nftToken, _tokenId, block.timestamp);
    }

    function batchTrust(address _nftToken, uint256[] memory _tokenIds) public nonReentrant {
        require(_nftToken != address(0), "NONEMPTY_ADDRESS");

        uint256 len = _tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            require((trustList[_nftToken][_tokenIds[i]].userAddress == address(0)), "TOKEN_ERROR");

            trustList[_nftToken][_tokenIds[i]].userAddress = msg.sender;
            IERC721(_nftToken).transferFrom(msg.sender, address(this), _tokenIds[i]);
        }

        emit BatchTrust(msg.sender, _nftToken, _tokenIds, block.timestamp);
    }

    function retrieveAuthorization(address _user, address _nftToken, uint256 _tokenId) public nonReentrant onlyAdmin {
        require((_user != address(0)) && (_nftToken != address(0)), "NONEMPTY_ADDRESS");
        require(_user != _nftToken, "ADDRESS_ERROR");
        require((trustList[_nftToken][_tokenId].userAddress == _user), "TOKEN_NOT_OWNER");

        trustList[_nftToken][_tokenId].retrievable = true;

        emit RetrieveAuthorization(_user, _nftToken, _tokenId, block.timestamp);
    }

    function batchRetrieveAuthorization(address _user, address _nftToken, uint256[] memory _tokenIds) public nonReentrant onlyAdmin {
        require((_user != address(0)) && (_nftToken != address(0)), "NONEMPTY_ADDRESS");
        require(_user != _nftToken, "ADDRESS_ERROR");
        uint256 len = _tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            require((trustList[_nftToken][_tokenIds[i]].userAddress == _user), "TOKEN_NOT_OWNER");
            trustList[_nftToken][_tokenIds[i]].retrievable = true;
        }

        emit BatchRetrieveAuthorization(_user, _nftToken, _tokenIds, block.timestamp);
    }

    function retrieve(address _nftToken, uint256 _tokenId) public payable nonReentrant {
        require((_nftToken != address(0)), "NONEMPTY_ADDRESS");
        require((trustList[_nftToken][_tokenId].userAddress == msg.sender), "TOKEN_NOT_OWNER");
        require((trustList[_nftToken][_tokenId].retrievable == true), "NO_PERMISSION_TO_RETRIEVE");

        trustList[_nftToken][_tokenId].userAddress = address(0);
        trustList[_nftToken][_tokenId].retrievable = false;
        if (feeAmount > 0 && feeTo != address(0)) {
            require(msg.value == feeAmount, "FEE_ERROR");
            address payable _feeTo = address(uint160(feeTo));
            _feeTo.transfer(feeAmount);
        }
        IERC721(_nftToken).safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Retrieve(msg.sender, _nftToken, _tokenId, block.timestamp);
    }

    function batchRetrieve(address _nftToken, uint256[] memory _tokenIds) public payable nonReentrant {
        require((_nftToken != address(0)), "NONEMPTY_ADDRESS");
        uint256 len = _tokenIds.length;

        if (feeAmount > 0 && feeTo != address(0)) {
            uint256 feeAmountTotal = feeAmount.mul(len);
            require(msg.value == feeAmountTotal, "FEE_ERROR");
            address payable _feeTo = address(uint160(feeTo));
            _feeTo.transfer(feeAmountTotal);
        }
        for (uint256 i = 0; i < len; i++) {
            require((trustList[_nftToken][_tokenIds[i]].userAddress == msg.sender), "TOKEN_NOT_OWNER");
            require((trustList[_nftToken][_tokenIds[i]].retrievable == true), "NO_PERMISSION_TO_RETRIEVE");
            trustList[_nftToken][_tokenIds[i]].userAddress = address(0);
            trustList[_nftToken][_tokenIds[i]].retrievable = false;
        }
        for (uint256 j = 0; j < len; j++) {
            IERC721(_nftToken).safeTransferFrom(address(this), msg.sender, _tokenIds[j]);
        }

        emit BatchRetrieve(msg.sender, _nftToken, _tokenIds, block.timestamp);
    }

    function batchBurn(address _nftToken, uint256[] memory _tokenIdList) public nonReentrant onlyAdmin {
        require(_nftToken != address(0), "NONEMPTY_ADDRESS");

        uint256 len = _tokenIdList.length;
        for (uint256 i = 0; i < len; i++) {
            trustList[_nftToken][_tokenIdList[i]].userAddress = address(0);
            trustList[_nftToken][_tokenIdList[i]].retrievable = false;
            CustomERC721(_nftToken).burnItem(_tokenIdList[i]);
        }

        emit BatchBurn(_nftToken, _tokenIdList);
    }

}