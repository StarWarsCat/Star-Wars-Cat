// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


interface ICat {
    struct TokenInfo {
        uint8 grade; // 1夏日猫 2未来猫 3电玩猫 4皇室猫 5猫后 6猫王
        uint8 stype; // grade为1-3的三种猫4个系列
        uint8 sex; // 1公猫  2母猫 默认公猫
        uint step; // 1幼年 2成年
        uint endTime;  // 到期时间
        uint initTime; // 初始时间
        uint feedTime; // 到期喂食时间
        uint tokenId; // 1猫王 2猫后 3-1999皇室猫 2000-~普通猫
        uint power; // 算力
        uint16 hp; // 生命值
        uint16 atk; // 攻击力
        uint16 def; // 防御
    }

    function currentTokenId() external view returns (uint);
    function royalTokenId() external view returns (uint);
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTokenInfo(uint _tokenId) external view returns (TokenInfo memory);
    function safeTransferFrom(address from, address to, uint tokenId) external;
    function mintOnlyBy(address _to, uint _tokenId , TokenInfo memory _tokenInfo) external returns (bool);
    function updateOnlyBy(uint _tokenId, TokenInfo memory _tokenInfo) external returns (bool);
    function burnOnlyBy(uint _tokenId) external returns (bool);
    function getTokenIdsOf(address _owner) external view returns (uint[] memory ids);
    function balanceOf(address owner) external view returns (uint256);
    function getNFTsOf(address _owner) external view returns (TokenInfo[] memory nfts);
    function getNFTsOf34(address _owner) external view returns (uint[2] memory);
}

interface ISlot {
    struct TokenInfo {
        uint8 grade; // 1夏日猫 2未来猫 3电玩猫 4皇室猫 5猫后 6猫王
        uint8 stype; // grade为1-3的三种猫4个系列 值为0-4
        uint tokenId;
    }

    function currentTokenId() external view returns (uint);
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTokenInfo(uint _tokenId) external view returns (TokenInfo memory);
    function safeTransferFrom(address from, address to, uint tokenId) external;
    function mintOnlyBy(address _to, uint _tokenId , TokenInfo memory _tokenInfo) external returns (bool);
    function burnOnlyBy(uint _tokenId) external returns (bool);
    function getTokenIdsOf(address _owner) external view returns (uint[] memory ids);
    function balanceOf(address owner) external view returns (uint256);
    function getNFTsOf(address _owner) external view returns (TokenInfo[] memory nfts);
}

interface IGoods {
    struct TokenInfo {
        uint id;
        uint tokenId;
        uint grade;
        uint stype;
        uint sex;
        uint priceType;
        uint initialPrice;
        uint price;
        uint initialTime;
        uint lastPriceTime;
        uint endTime;
        uint minPriceAmount;
        uint saleDuration;
        uint delayDuration;
        bool delayStart;
        address initialOwner;
        address owner;
    }

    function currentTokenId() external view returns (uint);
    function getTokens(address _account, uint _index, uint _offset) external view returns (TokenInfo[] memory tokens);
    function getTokenInfo(uint _tokenId) external view returns (TokenInfo memory);
    function add(address _to, uint _tokenId, TokenInfo memory _tokenInfo) external returns (bool);
    function update(uint _tokenId, TokenInfo memory _tokenInfo) external returns (bool);
    function remove(uint _tokenId) external returns (bool);
    function catTransfer(address to, uint _tokenId) external;
}

interface ISharePool {
    function setSharePool(address _pool) external;
    function updateWeight(address _sender, uint[2] memory _totalSuply, uint[2] memory _balance) external;
}
