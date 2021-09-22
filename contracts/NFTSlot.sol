// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./INFT.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";


interface IERC721 {
    //下面是ERC721的标准接口 http://erc721.org/
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed spender, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address spender);
    function setApprovalForAll(address spender, bool _approved) external;
    function isApprovedForAll(address owner, address spender) external view returns (bool);
}

interface IERC721Ex {
    //下面是ERC721的辅助接口
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
}


/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract NFTSlot is Context, IERC721, IERC721Ex, BaseUpgradeable {
    using SafeMath for uint256;
    using AddressUpgradeable for address;
    using EnumerableSet for EnumerableSet.UintSet;

    string private _name;
    string private _symbol;

    // 兑换产生的tokenid
    uint internal _currentTokenId; // 普通猫
    uint private _totalSupply;

    mapping(uint => address) public _ownerOf;
    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    mapping(uint => ISlot.TokenInfo) public _tokenInfoOf;          //TokenIdOwnerOf;    //TokenId => owner
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _spenderApprovals;

//    constructor() {
//        _name = "NFTSLOT";
//        _symbol = "Slot";
//        admin = msg.sender;
//    }

    function __NFTSlot_init() public initializer {
        BaseUpgradeable.__Base_init();

        _name = "NFTSLOT";
        _symbol = "Slot";
        admin = msg.sender;
        _currentTokenId = 0; // 普通猫
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view override returns (uint) {
        return _totalSupply;
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

    function getNFTsOf(address _owner) external view returns (ISlot.TokenInfo[] memory nfts) {
        uint len = _holderTokens[_owner].length();
        nfts = new ISlot.TokenInfo[](len);
        for (uint i = 0; i < len; i++) {
            nfts[i] = _tokenInfoOf[_holderTokens[_owner].at(i)];
        }
    }

    function getTokenId(address _account, uint _index) public view returns (uint tokenId) {
        return _holderTokens[_account].at(_index);
    }

    function getNFTs(address _account, uint _index, uint _offset) external view returns (ISlot.TokenInfo[] memory nfts) {
        uint totalSize = balanceOf(_account);
        require(0 < totalSize && totalSize > _index, "getNFTs: 0 < totalSize && totalSize > _index");
        if (totalSize < _index + _offset) {
            _offset = totalSize - _index;
        }

        nfts = new ISlot.TokenInfo[](_offset);
        for (uint i = 0; i < _offset; i++) {
            nfts[i] = getTokenInfo(getTokenId(_account, _index + i));
        }
    }

    function getTokenInfo(uint _tokenId) public view returns (ISlot.TokenInfo memory) {
        require(_tokenId <= _currentTokenId, "_tokenId <= _currentTokenId");
        return _tokenInfoOf[_tokenId];
    }

    /**
     * @dev mint only by auth account
     */
    function mintOnlyBy(address _to, uint _tokenId , ISlot.TokenInfo memory _tokenInfo) external onlyAuth notPaused returns (bool) {
        _mint(_to, _tokenId);
        _tokenInfoOf[_tokenId] = _tokenInfo;

        return true;
    }

    /**
     * @dev burn only by auth account
     */
    function burnOnlyBy(uint _tokenId) external onlyAuth notPaused returns (bool) {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: transfer caller is not owner nor approved");
        _burn(_tokenId);

        return true;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownerOf[tokenId];
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address spender, bool approved) public virtual override {
        require(spender != _msgSender(), "ERC721: approve to caller");

        _spenderApprovals[_msgSender()][spender] = approved;
        emit ApprovalForAll(_msgSender(), spender, approved);
    }

    function isApprovedForAll(address owner, address spender) public view override returns (bool) {
        return _spenderApprovals[owner][spender];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external virtual override {
        // safeTransferFrom(from, to, tokenId, "");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, "");
    }

    // function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
    //     require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    //     _safeTransfer(from, to, tokenId, _data);
    // }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        require(_data.length == 0, "_data.length == 0");        //新加的，不允许传递数据

        _transfer(from, to, tokenId);
        // require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return address(0) != _ownerOf[tokenId];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _mint(to, tokenId);
//        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        //下面一段是新加的, tokenid 必须顺序增加
        require(tokenId == _currentTokenId + 1, "tokenId err");
        _currentTokenId = _currentTokenId + 1;

        _holderTokens[to].add(tokenId);

        _ownerOf[tokenId] = to;
        _totalSupply = _totalSupply.add(1);

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        require(0 != tokenId, "_burn: 0 != tokenId");
        address owner = ownerOf(tokenId);
        require(address(0) != owner, "_burn: address(0) != owner");
        // Clear approvals
        _approve(address(0), tokenId);

        // Clear metadata (if any)
        if (0 != _tokenInfoOf[tokenId].tokenId) {
            delete _tokenInfoOf[tokenId];
        }

        _holderTokens[owner].remove(tokenId);

        delete _ownerOf[tokenId];
        _totalSupply = _totalSupply.sub(1);

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _ownerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId); // internal owner
    }

    // function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
}
