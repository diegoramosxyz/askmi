//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./askmi.sol";

// ERROR CODES
// ERR1: The selected address has not created an AskMi contract
// ERR2: This address already owns an AskMi instance

// @title A factory for AskMi contracts
// @author Diego Ramos
contract AskMiFactory {
    // @notice Array containing all AskMi instances
    address[] private _askMis;

    // @notice Index to query the askMis array by the owner's address
    mapping(address => uint256) private _askMisLookup;

    // @notice owner of the current AskMi factory
    address private _owner;

    // Record the instantiation of an AskMi contract
    // @param askMi Address of the newly instantiated AskMi contract
    event AskMiInstantiated(address askMi);

    constructor() {
        _owner = msg.sender;
        // Ocuppy the first element to easily perform lookups
        _askMis.push(address(0));
    }

    // @notice Get someone's AskMi instance
    function getMyAskMi(address owner) public view returns (address) {
        uint256 index = _askMisLookup[owner];
        require(index > 0, "ERR1");
        return _askMis[index];
    }

    // @notice Deploy an instance of an AskMi contract whose owner is the person calling the function
    // @param functionsContract Contract with functions to modify state in this contract
    // @param tiersToken Any ERC20 token or 0x0 for ETH
    // @param tipToken Any ERC20 token or 0x0 for ETH
    // @param tiers The tiers for the selected token
    // @param tip The cost for people to tip
    // @param removalFee The fee taken from the questioner to remove a question
    function instantiateAskMi(
        address tiersToken,
        address tipToken,
        uint256[] memory tiers,
        uint256 tip,
        uint256 removalFee
    ) public {
        require(_askMisLookup[msg.sender] == 0, "ERR2");

        // Instantiate AskMi contract
        AskMi askMi = new AskMi(
            _owner,
            msg.sender,
            tiersToken,
            tipToken,
            tiers,
            tip,
            removalFee
        );

        // Save the owner's index
        _askMisLookup[msg.sender] = _askMis.length;

        // Save the address of the new AskMi
        _askMis.push(address(askMi));

        emit AskMiInstantiated(address(askMi));
    }
}
