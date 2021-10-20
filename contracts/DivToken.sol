// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./INFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AdminBaseUpgradeable.sol";

// 分红合约，分红地址写死在里面
contract DivToken is AdminBaseUpgradeable {
    using SafeMath for uint;

    IERC20 public cpToken;

    mapping(uint => address)    public PeopleAddressOf;     // index => People address
    mapping(uint => uint)       public PeoplePer10000Of;    // People address => per100

    uint public PeopleCount;

    function __DivToken_init(address _cpToken) internal initializer {
        BaseUpgradeable.__Base_init();

        cpToken = IERC20(_cpToken);
        IniPeople();
    }

    // todo
    function IniPeople() internal {
        // 编号	比例	地址
        PeopleAddressOf[1] = 0x6e81CAb335A40f3690F6ba86C3B18D95e107d2aC;
        PeoplePer10000Of[1] = 10000;

        PeopleCount = 1;

        uint _sum = 0;
        for(uint i = 1; i <= PeopleCount; i++) {
            _sum = _sum + PeoplePer10000Of[i];
        }
        require(_sum == 10000, "_sum == 10000");
    }

    // 兑换ETH收益分配：
    function DivToPeopleEth(uint _ethAmount) internal {
        for (uint i = 1; i <= PeopleCount; i++) {
            address people = PeopleAddressOf[i];
            uint Per10000 = PeoplePer10000Of[i];
            uint PeopleEthAmount = _ethAmount * Per10000 / 10000;
            payable(people).transfer(PeopleEthAmount);
        }
    }

    function DivToPeopleCP(uint _amount) internal {
        for (uint i = 1; i <= PeopleCount; i++) {
            address people = PeopleAddressOf[i];
            uint Per10000 = PeoplePer10000Of[i];
            uint PeopleTokenAmount = _amount * Per10000 / 10000;
            IERC20(cpToken).transfer(people, PeopleTokenAmount);
        }
    }

}
