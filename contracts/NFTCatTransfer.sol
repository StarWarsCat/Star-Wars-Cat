// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./INFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NFTCatTransfer is Initializable {
    ICat public catAddr;
    IERC20 public payToken;
    // todo  分红地址
    address public taxAddr;

    uint public fee;

//    constructor(address _catAddr, address _payToken, address _taxAddr) {
//        catAddr = ICat(_catAddr);
//        payToken = IERC20(_payToken);
//        taxAddr = _taxAddr;
//    }

    function __NFTCatTransfer_init(address _catAddr, address _payToken, address _taxAddr) public initializer {
        catAddr = ICat(_catAddr);
        payToken = IERC20(_payToken);
        taxAddr = _taxAddr;
        fee = 1_0000 * 1e18;
    }

    function transferNftList(address _to, uint[] memory _tokenids) external returns(bool) {
        require(_tokenids.length < 50, "require length < 50");

        // 扣除转账费用
        uint amount = _tokenids.length * fee;
        payToken.transferFrom(msg.sender, taxAddr, amount);

        for (uint i = 0; i < _tokenids.length; i++) {
            catAddr.safeTransferFrom(msg.sender, _to, _tokenids[i]);
        }

        return true;
    }
}
