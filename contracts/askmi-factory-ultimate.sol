//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./askmi-ultimate.sol";

// ERROR CODES
// 1: The selected address has not created an AskMi contract
// 2: This address already owns an AskMi instance
// 3: Array length can't be 1 and the maximum amount of
//  tiers, which is 9 cannot be exceeded

// @title A factory for AskMi contracts
// @author Diego Ramos
contract AskMiFactoryUltimate {
    // @notice Array containing all AskMi instances
    address[] private askMis;

    // @notice Index to query the askMis array by the owner's address
    mapping(address => uint256) private askMisLookup;

    // @notice owner of the current AskMi factory
    address private owner;

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
            "1"
        );
        return askMis[askMiIndex];
    }

    function instantiateAskMi(uint256[] memory _tipAndTiers) public {
        // Only allow one AskMi instance per address
        require(askMisLookup[msg.sender] == 0, "2");
        uint256 _tipAndTiersSize = _tipAndTiers.length;
        // Check that the tiers array is not empty and not bigger than 3
        require(_tipAndTiersSize != 1 && _tipAndTiersSize <= 10, "3");

        // Instantiate AskMi contract
        AskMiUltimate _askMi = new AskMiUltimate(
            owner,
            msg.sender,
            _tipAndTiers
        );

        // Save the owner's index
        askMisLookup[msg.sender] = askMis.length;

        // Save the address of the new AskMi
        askMis.push(address(_askMi));

        emit AskMiInstantiated(address(_askMi));
    }
}
