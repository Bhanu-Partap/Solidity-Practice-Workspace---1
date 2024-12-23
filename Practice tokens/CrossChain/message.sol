// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

contract SimpleGeneralMessage is NonblockingLzApp {
    using BytesLib for bytes;

    mapping(address => string) public lastMessage;

    constructor(address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {}

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) override internal {
        (address sender, string memory message) = abi.decode(_payload, (address, string));
        lastMessage[sender] = message;
    }

    function sendMessage(string memory message, uint16 destChainId) external payable {
        bytes memory payload = abi.encode(msg.sender, message);
        _lzSend({
            _dstChainId: destChainId, 
            _payload: payload, 
            _refundAddress: payable(msg.sender), 
            _zroPaymentAddress: address(0x0), 
            _adapterParams: bytes(""), 
            _nativeFee: msg.value}
        );
    }
}