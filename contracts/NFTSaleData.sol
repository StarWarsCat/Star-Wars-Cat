// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTSaleData is BaseUpgradeable {
    using SafeMath for uint256;
    using AddressUpgradeable for address;
    using EnumerableSet for EnumerableSet.UintSet;

    uint internal _currentTokenId;
    uint private _totalSupply;
    ICat public catAddr;

    mapping(uint => address) public _ownerOf;
    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;
    mapping(uint => IGoods.TokenInfo) private _tokenInfoOf;          //TokenIdOwnerOf;    //TokenId => owner

//    constructor(address _addr) {
//        catAddr = ICat(_addr);
//    }

    function initialize(address _addr) public initializer {
        BaseUpgradeable.__Base_init();
        catAddr = ICat(_addr);
        _currentTokenId = 0;
    }

    function currentTokenId() public view returns (uint) {
        return _currentTokenId;
    }

    function getTokenIdsOf(address _owner) external view returns (uint[] memory ids) {
        uint len = _holderTokens[_owner].length();
        ids = new uint[](len);
        for (uint i = 0; i < len; i++) {
            ids[i] = _holderTokens[_owner].at(i);
        }
    }

    function getTokensOf(address _owner) external view returns (IGoods.TokenInfo[] memory tokens) {
        uint len = _holderTokens[_owner].length();
        tokens = new IGoods.TokenInfo[](len);
        for (uint i = 0; i < len; i++) {
            tokens[i] = _tokenInfoOf[_holderTokens[_owner].at(i)];
        }
    }

    function getTokenId(address _account, uint _index) public view returns (uint tokenId) {
        return _holderTokens[_account].at(_index);
    }

    function getTokens(address _account, uint _index, uint _offset) external view returns (IGoods.TokenInfo[] memory tokens) {
        uint totalSize = balanceOf(_account);
        require(0 < totalSize && totalSize > _index, "getNFTs: 0 < totalSize && totalSize > _index");
        if (totalSize < _index + _offset) {
            _offset = totalSize - _index;
        }

        tokens = new IGoods.TokenInfo[](_offset);
        for (uint i = 0; i < _offset; i++) {
            tokens[i] = getTokenInfo(getTokenId(_account, _index + i));
        }
    }

    function getTokenInfo(uint _tokenId) public view returns (IGoods.TokenInfo memory) {
        require(_tokenId <= _currentTokenId, "_tokenId <= _currentTokenId");
        return _tokenInfoOf[_tokenId];
    }

    function add(address _to, uint _tokenId, IGoods.TokenInfo memory _tokenInfo) external onlyAuth notPaused returns (bool) {
        require(_tokenId == _currentTokenId + 1, "_tokenId == _currentTokenId + 1");
        _tokenInfoOf[_tokenId] = _tokenInfo;
        _holderTokens[_to].add(_tokenId);
        _ownerOf[_tokenId] = _to;
        _currentTokenId = _currentTokenId + 1;

        _totalSupply = _totalSupply.add(1);

        return true;
    }

    function update(uint _tokenId, IGoods.TokenInfo memory _tokenInfo) external onlyAuth notPaused returns (bool) {
        require(_tokenInfoOf[_tokenId].tokenId > 0, "_tokenInfoOf[_tokenId].tokenId > 0");
        _tokenInfoOf[_tokenId] = _tokenInfo;
    }

    function remove(uint _tokenId) external onlyAuth notPaused returns (bool) {
        if (0 != _tokenInfoOf[_tokenId].tokenId) {
            delete _tokenInfoOf[_tokenId];
        }

        _holderTokens[_ownerOf[_tokenId]].remove(_tokenId);
        delete _ownerOf[_tokenId];

        _totalSupply = _totalSupply.sub(1);

        return true;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _holderTokens[owner].length();
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _ownerOf[tokenId];
    }

    function catTransfer(address to, uint _tokenId) external onlyAuth notPaused {
        catAddr.safeTransferFrom(address(this), to, _tokenId);
    }
}
