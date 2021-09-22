// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


interface IShop {
    function delItem(address _owner, uint _id, uint _val) external;
    function addItem(address _owner, uint _id, uint _val) external;
}
