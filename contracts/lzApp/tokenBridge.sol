pragma solidity ^0.7.6;

import "./NonblockingLzApp.sol";
import "../interfaces/IERC20.sol";

contract CrossChainToken is NonblockingLzApp {
    mapping(address => mapping(uint16 => address)) public localToRemote;
    mapping(address => mapping(uint16 => address)) public remoteToLocal;
    // mapping(uint16 => mapping(address => uint)) public totalValueLocked;
    uint public constant TOKEN_LOCK_UNLOCK = 1;
    uint public constant TOKEN_MINT_BURN = 2;
    mapping(address => uint) public typeTokenLocal;

    event RegisterToken(
        address localToken,
        uint16 remoteChainId,
        address remoteToken
    );

    constructor(address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {
        // if (_lzEndpoint == 0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1) destChainId = 10102; //sepolia
        // if (_lzEndpoint == 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1) destChainId = 10161; //bsc
    }

    function _nonblockingLzReceive(
        uint16 srcChainId,
        bytes memory,
        uint64,
        bytes memory _payload
    ) internal override {
        (address toAddress, address remoteToken, uint amount) = abi.decode(
            _payload,
            (address, address, uint)
        );
        address localToken = remoteToLocal[remoteToken][srcChainId];
        require(localToken != address(0), "token is not supported");
        if (typeTokenLocal[localToken] == TOKEN_LOCK_UNLOCK) {
            IERC20(localToken).transfer(toAddress, amount);
        } else if (typeTokenLocal[localToken] == TOKEN_MINT_BURN) {
            IERC20(localToken).burn(msg.sender, amount);
        }
    }

    function bridge(
        uint16 destChainId,
        address token,
        uint _amount
    ) external payable {
        // Supports tokens with transfer fee
        uint balanceBefore = IERC20(token).balanceOf(address(this));
        if (typeTokenLocal[token] == TOKEN_LOCK_UNLOCK) {
            IERC20(token).transferFrom(msg.sender, address(this), _amount);
        } else if (typeTokenLocal[token] == TOKEN_MINT_BURN) {
            IERC20(token).burn(msg.sender, _amount);
        }
        bytes memory payload = abi.encode(msg.sender, token, _amount);
        _lzSend(
            destChainId,
            payload,
            payable(msg.sender),
            address(0x0),
            bytes(""),
            msg.value
        );
    }

    function trustAddress(
        uint16 destChainId,
        address _otherContract
    ) public onlyOwner {
        trustedRemoteLookup[destChainId] = abi.encodePacked(
            _otherContract,
            address(this)
        );
    }

    function registerToken(
        address localToken,
        uint16 remoteChainId,
        address remoteToken,
        uint _typeTokenLocal
    ) external onlyOwner {
        require(localToken != address(0), "TokenBridge: invalid local token");
        require(remoteToken != address(0), "TokenBridge: invalid remote token");
        require(
            localToRemote[localToken][remoteChainId] == address(0) &&
                remoteToLocal[remoteToken][remoteChainId] == address(0),
            "TokenBridge: token already registered"
        );

        localToRemote[localToken][remoteChainId] = remoteToken;
        remoteToLocal[remoteToken][remoteChainId] = localToken;
        typeTokenLocal[localToken] = _typeTokenLocal;
        emit RegisterToken(localToken, remoteChainId, remoteToken);
    }
}
