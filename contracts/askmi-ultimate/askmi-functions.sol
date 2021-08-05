//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TODO:
// - Make the answers updatable
// - Maybe allow the responder to write an "AD" about his
// expertise, social media and others

// ERRORS CODES
// ERR2: Attempted to add a tier of cost 0
// ERR3: Must be owner to call function
// ERR4: Must not be owner to call function
// ERR5: Re-entrancy not allowed
// ERR6: Attempted to update tiers but did not include
// ERR8: The selected tier does not exist
// ERR9: The deposit is not equal to the tier price
// ERR10: This token is not supported
// ERR11: Error transfering funds ERC20
// ERR12: No questions available to remove
// ERR13: Selected question does not exist
// ERR14: Question has already been answered
// ERR15: Failed to send Ether
// ERR16: Exchange does not exist
// ERR17: The tip amount is incorrect
// ERR18: Cannot ask questions because the ask() function has been disabled
// ERR19: Tips are disabled

// @title Functions used to update the state of an AskMi instance
// @author Diego Ramos
contract AskMiFunctions {
    /* ---------- VARIABLES ---------- */

    // @notice The owner of this smart contract (askmi instance)
    address public _owner;

    // @dev Variable used to prevent re-entrancy
    bool private _locked;

    // @notice Prevents the ask() function from being called
    bool public _disabled;

    // @notice The tip cost and token address for all exchanges
    Tip private _tip;

    // @dev Address designated to receive all dev fees
    address private _developer;

    // @notice The developer fee and removal fee
    Fees public _fees;

    // @notice An array of all unique addresses which have asked a question
    address[] private _questioners;

    // @notice Mapping pointing to the possition of a questioner in the questioners array
    mapping(address => uint256) private _questionersIndex;

    // @notice The list of questions from a questioner
    mapping(address => Exchange[]) private _exchanges;

    // @notice List of token addresses accepted as payment by the responder
    address[] private _supportedTokens;

    // @dev Mapping pointing to the possition of supported tokens in the supportedTokens array
    mapping(address => uint256) private _supportedTokensIndex;

    // @dev The tiers for each supported token
    mapping(address => uint256[]) private _tiers;

    /* ---------- STRUCTS ---------- */

    // @dev The multihash representation of an IPFS' CID
    // @custom:struct digest The digest output of hash function in hex with prepended '0x'
    // @custom:struct hashFunction The hash function code for the function used
    // @custom:struct size The length of digest
    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    // @custom:struct token Address for the token used to pay to tip
    // @custom:struct tip Amount required to tip
    struct Tip {
        address token;
        uint256 tip;
    }

    // @custom:struct removal Fee paid to the responder for deleting a question. If the responder removes the question it's justified because he has to pay gas fees. If the questioner removes it, it's justified because the responder may have started working on an answer.
    // @custom:struct developer Fee paid to the developer of the project
    struct Fees {
        uint256 removal;
        uint256 developer;
    }

    // @dev exchange The exchange between the questioner asking as question and the responder answering it
    // @custom:struct question The CID containing the question
    // @custom:struct answer The CID containing the answer
    // @custom:struct token Address for the token used to pay to ask
    // @custom:struct index Index of the current exchange in the exchanges array
    // @custom:struct balance Amount paid to ask
    // @custom:struct tips Amount of times an answer has been tipped
    struct Exchange {
        Cid question;
        Cid answer;
        address token;
        uint256 index;
        uint256 balance;
        uint256 tips;
    }

    /* ---------- MODIFIERS ---------- */

    modifier onlyOwner() {
        require(msg.sender == _owner, "ERR3");
        _;
    }

    modifier notOwner() {
        require(msg.sender != _owner, "ERR4");
        _;
    }

    modifier noReentrant() {
        require(!_locked, "ERR5");
        _locked = true;
        _;
        _locked = false;
    }

    function toggleDisabled() external onlyOwner {
        _disabled = !_disabled;
    }

    /* ---------- UPDATE FUNCTIONS ---------- */

    // @notice Update the tiers for any token. If the new tiers array is empty, support for the selected token will be dropped. If the token was no supported and new tiers are added, support for the token will be enabled
    // @param token Any ERC20 token
    // @param tiers The tiers for the selected token
    function updateTiers(address token, uint256[] memory tiers)
        external
        onlyOwner
    {
        uint256 length = tiers.length;

        // If the input tiers array is empty support for the token will be dropped
        if (length == 0) {
            // Drop support for a token
            _tiers[token] = tiers;
            // Drop the selected token from _supportedTokens
            if (_supportedTokens.length != 0) {
                if (_supportedTokens.length == 1) {
                    // If there is only one address, just pop()
                    _supportedTokens.pop();
                } else {
                    {
                        // If there is more than one address, drop and shrink array
                        address lastAddress = _supportedTokens[
                            _supportedTokens.length - 1
                        ];

                        uint256 indexToBeReplaced = _supportedTokensIndex[
                            token
                        ];

                        _supportedTokensIndex[lastAddress] = indexToBeReplaced;

                        _supportedTokens[indexToBeReplaced] = lastAddress;

                        _supportedTokens.pop();
                    }
                }
            }
        } else {
            if (_tiers[token].length == 0) {
                // Update the _supportedTokens if needed
                _supportedTokensIndex[token] = _supportedTokens.length;
                _supportedTokens.push(token);
            }
            require(length > 0 && length < 10, "ERR6");
            for (uint256 i = 0; i < length; i++) {
                require(tiers[i] > 0, "ERR2");
            }

            // Add or update support for a token
            _tiers[token] = tiers;
        }
    }

    /* ---------- HELPER FUNCTIONS ---------- */

    // @notice Save the unique addresses of the questioners
    function addQuestioner() private {
        // Only push a new address into the array if it does NOT contain
        // the selected address
        if (msg.sender != address(0) && _questionersIndex[msg.sender] == 0) {
            // The min. value for the length of the array is 1, because
            // index 0 of the array always contains address(0)
            _questionersIndex[msg.sender] = _questioners.length;

            _questioners.push(msg.sender);
        }
    }

    /* ---------- PRIMARY FUNCTIONS ---------- */

    // @notice Ask a question to the owner
    // @param token Address of a supported token
    // @param digest The digest output of hash function in hex with prepended '0x'
    // @param hashFunction The hash function code for the function used
    // @param size The length of digest
    // @param index The index of the selected tier in the _tiers array
    function ask(
        address token,
        string memory digest,
        uint256 hashFunction,
        uint256 size,
        uint256 index
    ) external payable notOwner {
        require(!_disabled, "ERR18");

        uint256[] memory tiers = _tiers[token];

        // Check that the tier exists
        require(index < tiers.length, "ERR8");

        if (token == address(0)) {
            require(msg.value == tiers[index], "ERR9");
        } else {
            // Check that the input ERC20 is supported
            require(tiers.length != 0, "ERR10");

            IERC20 erc20 = IERC20(token);

            require(
                erc20.transferFrom(msg.sender, address(this), tiers[index]),
                "ERR11"
            );
        }

        // Save new questioners
        addQuestioner();

        Cid memory question = Cid({
            digest: digest,
            hashFunction: hashFunction,
            size: size
        });

        // Initialize answer object with default values
        Cid memory answer;

        // Save the new exchange
        _exchanges[msg.sender].push(
            Exchange({
                question: question,
                answer: answer,
                token: token,
                balance: tiers[index],
                index: _exchanges[msg.sender].length,
                tips: 0
            })
        );
    }

    // @notice The questioner or the responder can remove a question and a refund is issued
    // @param questioner The questioner's address
    // @param index Index of the selected exchange in the questioners' exchanges array
    function remove(address questioner, uint256 index) external noReentrant {
        // Only allow the owner to remove questions from any questioner
        address questioner_;
        if (msg.sender == _owner) {
            questioner_ = questioner;
        } else {
            questioner_ = msg.sender;
        }

        // Get all the exchanges from a questioner
        Exchange[] storage exchanges = _exchanges[questioner_];

        // Stop execution if the questioner has no questions
        require(exchanges.length > 0, "ERR12");

        // Check that the question exists
        require(index < exchanges.length, "ERR13");

        // Check that the question has not been answered
        // An empty string is the default value for a string
        require(
            keccak256(bytes(exchanges[index].answer.digest)) ==
                keccak256(bytes("")),
            "ERR14"
        );

        // Create payment variables
        uint256 balance = exchanges[index].balance;

        uint256 removalFee = (balance) / _fees.removal;
        uint256 refund = balance - removalFee;

        address token = exchanges[index].token;

        if (token == address(0)) {
            // Pay removal fee
            (bool feeSuccess, ) = _owner.call{value: removalFee}("");
            require(feeSuccess, "ERR15");
            // Issue refund
            (bool refundSuccess, ) = questioner.call{value: refund}("");
            require(refundSuccess, "ERR15");
        } else {
            // Check that the ERC20 is supported
            require(_tiers[token].length != 0, "ERR10");

            IERC20 erc20 = IERC20(token);

            // Pay removal fee
            require(erc20.transfer(_owner, removalFee), "ERR11");
            // Issue refund
            require(erc20.transfer(questioner, refund), "ERR11");
        }

        if (exchanges.length == 1) {
            // In this case, the questioner is removing their last question
            // 1- Remove his address from the questioners array
            // 2- Reset questionersIndex (default value of uint is 0)
            // 3- Remove the last exchange from the exchanges array

            // 0xabc is calling the function

            // [0x0, 0xabc, 0x123]
            // 0xabc -> 1
            // 0x123 -> 2

            // Get the last questioner in the array
            address lastQuestioner = _questioners[_questioners.length - 1];

            // Get the index for the function caller
            uint256 callerIndex = _questionersIndex[questioner_];

            // Change the index to that of the questioner to be deleted
            _questionersIndex[lastQuestioner] = callerIndex;

            // [0x0, 0xabc, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Use the last questioner to overwrite the questioner to be deleted
            _questioners[callerIndex] = lastQuestioner;

            // [0x0, 0x123, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Remove the last element/duplicate
            _questioners.pop();

            // [0x0, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Set questionersIndex to the default value: 0
            _questionersIndex[questioner] = 0;

            // [0x0, 0x123]
            // 0xabc -> 0
            // 0x123 -> 1

            // Remove the last element
            exchanges.pop();
        } else {
            // Delete an element and shrink array

            // Get the last element of the array
            Exchange memory lastExchange = exchanges[exchanges.length - 1];

            // Change its index value to match new index
            lastExchange.index = index;

            // Use the last element to overwrite the element to be deleted
            exchanges[index] = lastExchange;

            // Remove the last element/duplicate
            exchanges.pop();
        }
    }

    // @notice The owner answers a question
    // @param questioner The questioner's address
    // @param digest The digest output of hash function in hex with prepended '0x'
    // @param hashFunction The hash function code for the function used
    // @param size The length of digest
    // @param index Index of the selected exchange in the questioners' exchanges array
    function respond(
        address questioner,
        string memory digest,
        uint256 hashFunction,
        uint256 size,
        uint256 index
    ) external noReentrant onlyOwner {
        // Get all the exchanges from a questioner
        Exchange[] storage exchanges = _exchanges[questioner];

        // Check that the exchange exists
        require(index < exchanges.length, "ERR16");

        // Get the balance of the selected exchange
        uint256 balance = exchanges[index].balance;

        // Create payment variables
        uint256 devFee = (balance) / _fees.developer;
        uint256 payment = balance - devFee;

        address token = exchanges[index].token;

        if (token == address(0)) {
            // Pay the owner of the contract (The Responder)
            (bool success, ) = _owner.call{value: payment}("");
            require(success, "ERR15");
            // Pay dev fee
            (bool devSuccess, ) = _developer.call{value: devFee}("");
            require(devSuccess, "ERR15");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(_tiers[token].length != 0, "ERR10");

            IERC20 erc20 = IERC20(token);

            // Pay the owner of the contract (The Responder)
            require(erc20.transfer(_owner, payment), "ERR11");
            require(erc20.transfer(_developer, devFee), "ERR11");
        }

        Cid memory answer = Cid({
            digest: digest,
            hashFunction: hashFunction,
            size: size
        });

        // Get the selected exchange
        Exchange memory exchange = exchanges[index];

        // Update the selected exchange
        exchange.answer = answer;
        exchange.balance = 0;

        exchanges[index] = exchange;
    }

    // @notice Update the tip amount and the supported token for tipping
    // @param tip The cost for people to tip
    // @param token Any ERC20 token
    function updateTip(uint256 tip, address token) external {
        _tip = Tip({token: token, tip: tip});
    }

    // @notice Tip an exchange to highlight helpful content
    // @param questioner The questioner's address
    // @param index Index of the selected exchange in the questioners' exchanges array
    function issueTip(address questioner, uint256 index)
        external
        payable
        notOwner
    {
        // Check that tips aren't disabled
        require(_tip.tip > 0, "ERR19");
        // Get all the exchanges from a questioner
        Exchange[] storage exchanges = _exchanges[questioner];

        // Check that the exchange exists
        require(index < exchanges.length, "ERR16");

        // Pay the owner of the contract (The Responder)
        // TODO: Split the tip among the responder, the questioner and the dev
        address token = exchanges[index].token;
        uint256 tip = _tip.tip;

        if (_tip.token == address(0)) {
            // Check that the tip amount is correct
            require(msg.value == tip, "ERR17");
            (bool success, ) = _owner.call{value: msg.value}("");
            require(success, "ERR15");
        } else {
            IERC20 erc20 = IERC20(token);
            require(erc20.transferFrom(msg.sender, _owner, tip), "ERR11");
        }

        // Get the selected exchange
        Exchange memory exchange = exchanges[index];

        // Increment the tip count
        exchange.tips = exchanges[index].tips + 1;

        // Update the selected exchange
        exchanges[index] = exchange;
    }
}
