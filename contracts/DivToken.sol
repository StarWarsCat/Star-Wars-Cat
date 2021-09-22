// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// 分红合约，分红地址写死在里面
contract DivToken is BaseUpgradeable {
    using SafeMath for uint;

    IERC20 public cpToken;

    //    constructor(address _cpToken) {
    //        cpToken = IERC20(_cpToken);
    //        IniPeople();
    //    }

    function __DivToken_init(address _cpToken) public initializer {
        BaseUpgradeable.__Base_init();
        cpToken = IERC20(_cpToken);
        IniPeople();
        PeopleCount = 0;
    }

    mapping(uint => address)    public PeopleAddressOf;     // index => People address
    mapping(uint => uint)       public PeoplePer10000Of;    // People address => per100

    uint public PeopleCount;

    // todo
    function IniPeople() internal {
        // 编号	比例	地址
        PeopleAddressOf[1] = 0x2D899D21dc5Ee8bF7dA798555b26EF3828cB8309;
        PeoplePer10000Of[1] = 5000;

        PeopleAddressOf[2] = 0x8eE54B97941A09b6D5E40A9884d4150b09cfac9B;
        PeoplePer10000Of[2] = 1000;

        PeopleAddressOf[3] = 0x26e2bC1fd8F30aC51cF9D315c091d3a4e6d2672a;
        PeoplePer10000Of[3] = 600;

        PeopleAddressOf[4] = 0x6e81CAb335A40f3690F6ba86C3B18D95e107d2aC;
        PeoplePer10000Of[4] = 1500;

        PeopleAddressOf[5] = 0x22e04b93E75634b6F350844B5F7Bcab5775fdD80;
        PeoplePer10000Of[5] = 900;

        PeopleAddressOf[6] = 0x366034a33B3A4609d56FF494172E1c469dd83e5a;
        PeoplePer10000Of[6] = 500;

        PeopleAddressOf[7] = 0x801EE97e899d78024d0bbC2fD7f1Ac7919415B54;
        PeoplePer10000Of[7] = 500;

        PeopleCount = 7;

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

    ///////////////////////////////// admin function /////////////////////////////////
    event AdminWithdrawNFT(address operator, address indexed to, uint indexed tokenId);
    event AdminWithdrawToken(address operator, address indexed tokenAddress, address indexed to, uint amount);

    /**
     * @dev adminWithdrawNFT
     */
    function adminWithdrawNFT(address _addr, address _to, uint _tokenId) external onlyAdmin returns (bool) {
        IERC721(_addr).safeTransferFrom(address(this), _to, _tokenId);
        emit AdminWithdrawNFT(msg.sender, _to, _tokenId);
        return true;
    }

    /**
     * @dev adminWithdrawToken
     */
    function adminWithdrawToken(address _token, address _to, uint _amount) external onlyAdmin returns (bool) {
        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_token).transfer(_to, _amount);
        }

        emit AdminWithdrawToken(msg.sender, _token, _to, _amount);
        return true;
    }
}
