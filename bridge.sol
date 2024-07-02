// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bridge is NonblockingLzApp {
    mapping(address => mapping(uint16 => address)) public localToRemote;
    mapping(address => mapping(uint16 => address)) public remoteToLocal;
    // mapping(uint16 => mapping(address => uint)) public totalValueLocked;

    event RegisterToken(address localToken, uint16 remoteChainId, address remoteToken);

    constructor(address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {
        // if (_lzEndpoint == 0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1) destChainId = 10102; //sepolia
        // if (_lzEndpoint == 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1) destChainId = 10161; //bsc
    }

    function _nonblockingLzReceive(uint16 srcChainId, bytes memory, uint64, bytes memory _payload) internal override {
        (address toAddress, address remoteToken, uint amount) = abi.decode(_payload, (address, address, uint));
        address localToken = remoteToLocal[remoteToken][srcChainId];
        if (localToken == address(0)) {
            if (remoteToken == localToRemote[address(0)][srcChainId]) {
                (bool success, ) = toAddress.call{value: amount}("");
                require(success, "fail to receive coinbase");
            }
        } else {
            IERC20(localToken).transfer(toAddress, amount);
        }
    }

    function bridge(uint16 destChainId, address token, uint _amount) external payable {
        // Supports tokens with transfer fee
        bytes memory payload = abi.encode(msg.sender, token, _amount);
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), _amount);

            _lzSend(destChainId, payload, payable(msg.sender), address(0x0), bytes(""), msg.value);
        } else {
            uint fee = msg.value - _amount;
            _lzSend(destChainId, payload, payable(msg.sender), address(0x0), bytes(""), fee);
        }
    }

    function trustAddress(uint16 destChainId, address _otherContract) public onlyOwner {
        trustedRemoteLookup[destChainId] = abi.encodePacked(_otherContract, address(this));
    }

    function registerToken(address localToken, uint16 remoteChainId, address remoteToken) external onlyOwner {
        // require(localToken != address(0), "TokenBridge: invalid local token");
        // require(remoteToken != address(0), "TokenBridge: invalid remote token");
        // require(
        //     localToRemote[localToken][remoteChainId] == address(0) && remoteToLocal[remoteToken][remoteChainId] == address(0),
        //     "TokenBridge: token already registered"
        // );

        localToRemote[localToken][remoteChainId] = remoteToken;
        remoteToLocal[remoteToken][remoteChainId] = localToken;
        emit RegisterToken(localToken, remoteChainId, remoteToken);
    }

    function deposit() external payable {}
}
