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
        PeopleAddressOf[1] = 0xC78be2f6a4bd79e098806Bb91343Ca11d885d1f6;
        PeoplePer10000Of[1] = 700;

        PeopleAddressOf[2] = 0x926e7ee0Eb81266f80d434805c88a4c0043a2D59;
        PeoplePer10000Of[2] = 700;

        PeopleAddressOf[3] = 0xd9eda60883ac4E880593E43047E3b1AAA331bd23;
        PeoplePer10000Of[3] = 5000;

        PeopleAddressOf[4] = 0x57659746d9c6942259C6b4f34189CBB7A4983932;
        PeoplePer10000Of[4] = 1200;

        PeopleAddressOf[5] = 0x0ef3EbC0CdF81c7fBC08B4Abd382F20F5Ec2Ef5A;
        PeoplePer10000Of[5] = 400;

        PeopleAddressOf[6] = 0x26e2bC1fd8F30aC51cF9D315c091d3a4e6d2672a;
        PeoplePer10000Of[6] = 500;

        PeopleAddressOf[7] = 0x6e81CAb335A40f3690F6ba86C3B18D95e107d2aC;
        PeoplePer10000Of[7] = 1500;

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
