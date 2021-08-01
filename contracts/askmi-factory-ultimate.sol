//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./askmi-ultimate.sol";

// @title A factory for AskMi contracts
// @author Diego Ramos
contract AskMiFactoryUltimate {
    // @notice Array containing all AskMi instances
    address[] internal askMis;

    // @notice Index to query the askMis array by the owner's address
    mapping(address => uint256) internal askMisLookup;

    // @notice owner of the current AskMi factory
    address internal owner;

    // Record the instantiation of an AskMi contract
    event AskMiInstantiated(address _askMiAddress);

    constructor() {
        owner = msg.sender;
        // Ocuppy the first element to easily perform lookups
        askMis.push(address(0));
    }

    // @notice Get someone's AskMi instance
    function getMyAskMi(address _owner) public view returns (address) {
        uint256 askMiIndex = askMisLookup[_owner];
        require(
            // askMisIndexedByOwner will return 0 as a default value
            askMiIndex > 0,
            "The selected address has not created an AskMi contract."
        );
        return askMis[askMiIndex];
    }

    function instantiateAskMi(uint256[] memory _tiers) public {
        // Only allow one AskMi instance per address
        require(
            askMisLookup[msg.sender] == 0,
            "This address already owns an AskMi instance."
        );
        uint256 _tiersSize = _tiers.length;
        // Check that the tiers array is not empty and not bigger than 3
        require(
            _tiersSize > 0 && _tiersSize <= 3,
            "There must be between 1 and 3 tiers."
        );

        // Instantiate AskMi contract
        AskMiUltimate _askMi = new AskMiUltimate(owner, msg.sender, _tiers);

        // Save the owner's index
        askMisLookup[msg.sender] = askMis.length;

        // Save the address of the new AskMi
        askMis.push(address(_askMi));

        emit AskMiInstantiated(address(_askMi));
    }
}
