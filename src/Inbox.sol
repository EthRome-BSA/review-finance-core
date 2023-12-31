// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IInbox} from "src/interfaces/IInbox.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import "sismo-connect-solidity/SismoConnectLib.sol";
import {Structs} from "src/libraries/structs.sol";

contract Inbox is IInbox, SismoConnect {
    using SismoConnectHelper for SismoConnectVerifiedResult;
    // Events
    event RequestEmited(bytes nameEncoded);
    event ProtocolRegistered(bytes nameEncoded);
    event ReviewEmited(Structs.Review review);

    // Errors
    error ProtocolNotRegistered(bytes name);
    error NotAContract(address _address);
    error NotRegisteredForReview(address _address, string message);

    mapping(address => mapping(address => uint256))
        private userToContractVisitationFreq;
    mapping(uint256 => bytes) reviewersToReview;

    IRegistry registry;
    bytes16 private appId;
    bool private _isImpersonationMode = true;
    string name;

    // Constructor
    constructor(
        bytes16 _appId,
        string memory _name,
        address _registryAddress
    )
     SismoConnect(buildConfig(_appId, _isImpersonationMode)) {
        appId = _appId;
        name = _name;
        registry = IRegistry(_registryAddress);
    }

    /**
     * Function to register the contract's name
     * @param caller : Caller of the register function
     */

    function registerContract(address caller) external {
        if (_isContract(caller)) {
            registry.writeToATPNRegistry(caller, name);
            emit ProtocolRegistered(abi.encode(name));
        } else {
            revert NotAContract(caller);
        }
    }

    /**
     * Function to register the call by the user of some contract
     * @param caller : address of the caller
     * @param contractAddress : address of the contract calling the function
     */

    function registerCall(address caller, address contractAddress) external {
        bytes memory nameEncoded = abi.encode(name);

        if (registry.getProtocolName(contractAddress).length == 0) {
            revert ProtocolNotRegistered(nameEncoded);
        }

        if (!_isContract(contractAddress)) {
            revert NotAContract(contractAddress);
        }

        userToContractVisitationFreq[caller][contractAddress] += 1;
        emit RequestEmited(nameEncoded);
    }

    /**
     * Function to write and emit a review. We verify the proof submitted by the person attempting
     the review, if the proof is incorrect, Sismo will revert, else we write the review in the 
     registry. 
     * @param review : review to write
     * @param response : response bytes containing the proof.
     */
    function propagateReview(
        Structs.Review memory review,
        bytes memory response
    ) external {
        verify({
            responseBytes: response,
            auth: buildAuth({authType: AuthType.VAULT}),
            signature: buildSignature({message: abi.encode(tx.origin, review)})
        });

        registry.writeToNTRRegistry(review);
        emit ReviewEmited(review);
    }

    /**
     * Function to verify if an address is a contract
     * @param _candidateAddress : address to verify
     */

    function _isContract(
        address _candidateAddress
    ) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_candidateAddress)
        }
        return size == 0;
    }
}
