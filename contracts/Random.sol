// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Random is Initializable {
    uint public seed;
    uint constant MOD = 1e18;

    function __Random_init() public initializer {
        seed = uint160(address(this)) % MOD;
    }

    function seed0() public returns (uint) {
        seed = (seed + block.number) % MOD;
        return seed;
    }

    // 从列表中随机出一个
    function rand_list(uint[] memory _list) public returns(uint) {
        require(_list.length > 0, "rand_list error");

        uint _rand = uint(keccak256(abi.encodePacked(seed0(), msg.sender, block.timestamp, block.coinbase, address(this), gasleft()))) % _list.length;

        return _list[_rand];
    }

    // 随机一个100以内的数
    function rand100() public returns(uint) {
        return uint(keccak256(abi.encodePacked(seed0(), msg.sender, block.timestamp, block.coinbase, address(this), gasleft()))) % 100;
    }

    // 随机一个10000以内的数
    function rand10000() public returns(uint) {
        return uint(keccak256(abi.encodePacked(seed0(), msg.sender, block.timestamp, block.coinbase, address(this), gasleft()))) % 10000;
    }

    // 给定种子 以及 权重列表  随机给出权重列表的位置
    function rand_weight(uint[] memory _weight) public returns(uint) {
        uint _sum = 0;
        for (uint i = 0; i < _weight.length; i++) {
            _sum += _weight[i];
        }

        uint _rand = uint(keccak256(abi.encodePacked(seed0(), msg.sender, block.timestamp, block.coinbase, address(this), gasleft()))) % _sum;

        uint _sum2 = 0;
        for (uint i = 0; i < _weight.length; i++) {
            _sum2 += _weight[i];
            if (_sum2 >= _rand) {
                return i;
            }
        }

        require(1 == 0, "weight error");

        return 0;
    }

    function rand_weight_list(uint[2][] memory _weight) public returns(uint) {
        uint _sum = 0;
        for (uint i = 0; i < _weight.length; i++) {
            _sum += _weight[i][1];
        }

        uint _rand = uint(keccak256(abi.encodePacked(seed0(), msg.sender, block.timestamp, block.coinbase, address(this), gasleft()))) % _sum;

        uint _sum2 = 0;
        for (uint i = 0; i < _weight.length; i++) {
            _sum2 += _weight[i][1];
            if (_sum2 >= _rand) {
                return i;
            }
        }

        require(1 == 0, "weight error");

        return 0;
    }
}
