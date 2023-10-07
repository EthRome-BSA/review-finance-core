// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {GelatoVRFConsumer} from "contracts/GelatoVRFConsumer.sol";

/// @title GelatoVRFConsumerBase
/// @dev This contract handles domain separation between consecutive randomness requests
/// The contract has to be implemented by contracts willing to use the gelato VRF system.
/// This base contract enhances the GelatoVRFConsumer by introducing request IDs and
/// ensuring unique random values.
/// for different request IDs by hashing them with the random number provided by drand.
/// For security considerations, refer to the Gelato documentation.
abstract contract GelatoVRFConsumerBase is GelatoVRFConsumer {
    bool[] public requestPending;

    /// @notice Returns the address of the dedicated msg.sender.
    /// @dev The operator can be found on the Gelato dashboard after a VRF is deployed.
    /// @return Address of the operator.
    function _operator() internal view virtual returns (address);

    /// @notice Requests randomness from the Gelato VRF.
    /// @dev The extraData parameter allows for additional data to be passed to
    /// the VRF, which is then forwarded to the callback. This is useful for
    /// request tracking purposes if requestId is not enough.
    /// @param extraData Additional data for the randomness request.
    /// @return requestId The ID for the randomness request.
    function _requestRandomness(bytes memory extraData) internal returns (uint64 requestId) {
        requestId = uint64(requestPending.length);
        requestPending.push();
        requestPending[requestId] = true;
        bytes memory data = abi.encode(requestId, extraData);
        emit RequestedRandomness(data);
    }

    /// @notice User logic to handle the random value received.
    /// @param randomness The random number generated by Gelato VRF.
    /// @param requestId The ID for the randomness request.
    /// @param extraData Additional data from the randomness request.
    function _fulfillRandomness(uint256 randomness, uint64 requestId, bytes memory extraData) internal virtual;

    /// @notice Callback function used by Gelato VRF to return the random number.
    /// The randomness is derived by hashing the provided randomness with the request ID.
    /// @param randomness The random number generated by Gelato VRF.
    /// @param data Additional data provided by Gelato VRF, typically containing request details.
    function fulfillRandomness(uint256 randomness, bytes calldata data) external {
        require(msg.sender == _operator(), "only operator");
        (uint64 requestId, bytes memory extraData) = abi.decode(data, (uint64, bytes));
        randomness = uint256(keccak256(abi.encode(randomness, address(this), block.chainid, requestId)));
        if (requestPending[requestId]) {
            _fulfillRandomness(randomness, requestId, extraData);
            requestPending[requestId] = false;
        }
    }
}
