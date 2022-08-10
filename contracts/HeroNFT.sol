// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HeroNFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    address[] public adminList;

    mapping(uint256 => uint256) public propertyList;    //tokenId => propertyId

    bool hasProperty = false;

    Counters.Counter private _tokenIds;

    event MintItem(address recipient, address _token, uint256 tokenId, uint256 propertyId, uint256 _at);
    event MintMulti(address[] recipient, address _token, uint256[] tokenIds, uint256[] propertyIds, uint256 _at);
    event BurnItem(address recipient, address _token, uint256 tokenId, uint256 propertyId, uint256 _at);

    constructor() public ERC721("HeroNFT", "HeroNFT") {
        adminList.push(msg.sender);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory, uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return (new uint256[](0), new uint256[](0));
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256[] memory result2 = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
                result2[index] = propertyList[result[index]];
            }
            return (result, result2);
        }
    }

    function mintItem(address recipient, uint256 propertyId) public nonReentrant returns (uint256){
        require(onlyAdmin(msg.sender), "Only administrators can operate");
        require(recipient != address(0), "recipient is zero address");

        _tokenIds.increment();
        uint256 mintIndex = _tokenIds.current();

        _mint(recipient, mintIndex);
        propertyList[mintIndex] = propertyId;

        emit MintItem(recipient, address(this), mintIndex, propertyId, block.timestamp);

        return mintIndex;
    }

    function mintMulti(address[] calldata recipient, uint256[] calldata propertyIds) external nonReentrant returns (uint256[] memory){
        require(onlyAdmin(msg.sender), "Only administrators can operate");
        require(recipient.length > 0, "Receiver is empty");
        require(recipient.length == propertyIds.length, "Inconsistent array length");

        uint256 len = recipient.length;
        uint256[] memory tokenIds = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            _tokenIds.increment();
            uint256 mintIndex = _tokenIds.current();
            _mint(recipient[i], mintIndex);
            propertyList[mintIndex] = propertyIds[i];
            tokenIds[i] = mintIndex;
        }

        emit MintMulti(recipient, address(this), tokenIds, propertyIds, block.timestamp);

        return tokenIds;
    }

    function burnItem(uint256 tokenId) public nonReentrant returns (uint256)  {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);

        uint256 propertyId = propertyList[tokenId];
        emit BurnItem(tx.origin, address(this), tokenId, propertyId, block.timestamp);

        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        uint256 _propId = propertyList[tokenId];

        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (hasProperty) {
            return string(abi.encodePacked(baseURI(), _propId.toString(), '/', tokenId.toString()));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(baseURI(), tokenId.toString()));
    }

    function setAdminList(address[] memory _list) public onlyOwner nonReentrant {
        require(_list.length > 0, "_list is empty");

        for (uint256 nIndex = 0; nIndex < _list.length; nIndex++) {
            require(_list[nIndex] != address(0), "admin is empty");
        }
        adminList = _list;
    }

    function getAdminList() public view returns (address[] memory) {
        return adminList;
    }

    function onlyAdmin(address token) internal view returns (bool) {
        for (uint256 nIndex = 0; nIndex < adminList.length; nIndex++) {
            if (adminList[nIndex] == token) {
                return true;
            }
        }
        return false;
    }

}
