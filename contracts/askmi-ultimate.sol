//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TODO:
// - Add an upper bound for tiers. Like 10 max
// - Make the answers updatable
// - Maybe allow the responder to write an "AD" about his
// expertise, social media and others.
// - Set a min. value to charge per question

// RESPONDER: The owner of the contract.
// QUESTIONER: Anyone who asks a question.
// EXCHANGE: The exchange between the questioner asking
// as question and the responder answering

// ERRORS CODES
// 1: Tiers amount exceeds the maximum of 9.
// 2: Attempted to add a tier of cost 0.
// 3: Must be owner to call function.
// 4: Must not be owner to call function.
// 5: Re-entrancy not allowed.
// 6: Attempted to update tiers but did not include
// a tip price and at least on tier price
// 7: The tiers index start at index 1
// 8: The selected tier does not exist
// 9: The deposit is not equal to the tier price
// 10: This token is not supported
// 11: Error transfering funds ERC20
// 12: No questions available to remove
// 13: Selected question does not exist
// 14: Question has already been answered
// 15: Failed to send Ether
// 16: Exchange does not exist
// 17: The tip amount is incorrect.

// @title A question-and-answer smart contract
// @author Diego Ramos
contract AskMiUltimate {
    /* ---------- STRUCTS ---------- */

    // The multihash representation of an IPFS' CID
    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    struct Exchange {
        Cid question;
        Cid answer;
        address tokenAddress;
        uint256 exchangeIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
        uint256 tips;
    }

    /* ---------- VARIABLES ---------- */

    address[] private supportedTokens;

    mapping(address => uint256) private supportedTokensIndex;

    // @dev Find a token and its data using its address
    mapping(address => uint256[]) private tipAndTiers;

    // @notice The owner of this smart contract
    address public owner;

    // @notice The developer's address which receives the dev fee
    address private dev;

    // @notice The fee sent to the developer (balance/200 = 0.5%)
    uint256 public fee = 200;

    // @notice The list of questions from a questioner
    mapping(address => Exchange[]) private exchanges;

    // @notice Helper mapping to find specific questioners
    // This is used to modify the questioners array
    mapping(address => uint256) private questionersIndex;

    // @notice An array of all unique addresses which have asked a question
    address[] private questioners;

    // @notice Variable used to prevent re-entrancy
    bool private locked;

    /* ---------- CONSTRUCTOR ---------- */

    // @param _dev The developer's address which receives the dev fee
    // @param _owner The owner of the current contract
    // @param _tiers The prices to ask a question
    constructor(
        address _dev,
        address _owner,
        uint256[] memory _tipAndTiers
    ) {
        checkTipAndTiers(address(0), _tipAndTiers);

        dev = _dev;
        owner = _owner;

        // Occupy the first index
        questioners.push(address(0));
        if (_tipAndTiers.length >= 2) {
            supportedTokens.push(address(0));
        }
    }

    // Make the smart contract payable
    receive() external payable {}

    /* ---------- EVENTS ---------- */

    event QuestionAnswered(address _questioner, uint256 _exchangeIndex);

    /* ---------- MODIFIERS ---------- */

    modifier onlyOwner() {
        require(msg.sender == owner, "3");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "4");
        _;
    }

    modifier noReentrant() {
        require(!locked, "5");
        locked = true;
        _;
        locked = false;
    }

    /* ---------- GETTER FUNCTIONS ---------- */

    // @notice Get the complete tiers array
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    // @notice Get the complete tiers array
    function getTipAndTiers(address _tokenAddress)
        external
        view
        returns (uint256[] memory)
    {
        return tipAndTiers[_tokenAddress];
    }

    // @notice Get the complete questioners array.
    function getQuestioners() external view returns (address[] memory) {
        return questioners;
    }

    // @notice Get all of the questions asked by one questioner
    function getQuestions(address _questioner)
        external
        view
        returns (Exchange[] memory)
    {
        return exchanges[_questioner];
    }

    /* ---------- UPDATE FUNCTIONS ---------- */

    // @notice Update the tip and tiers array
    function updateTipAndTiers(
        address _tokenAddress,
        uint256[] memory _newTipAndTiers
    ) external onlyOwner {
        checkTipAndTiers(_tokenAddress, _newTipAndTiers);
    }

    /* ---------- HELPER FUNCTIONS ---------- */

    function checkTipAndTiers(
        address _tokenAddress,
        uint256[] memory _tipAndTiers
    ) private {
        uint256 _tipAndTiersSize = _tipAndTiers.length;

        if (_tipAndTiersSize == 0) {
            // Drop support for ETH or an ERC20 token.
            tipAndTiers[_tokenAddress] = _tipAndTiers;
            // Delete token and shrink array
            if (supportedTokens.length != 0) {
                if (supportedTokens.length == 1) {
                    supportedTokens.pop();
                } else {
                    {
                        address lastAddress = supportedTokens[
                            supportedTokens.length - 1
                        ];

                        uint256 indexToBeReplaced = supportedTokensIndex[
                            _tokenAddress
                        ];

                        supportedTokensIndex[lastAddress] = indexToBeReplaced;

                        supportedTokens[indexToBeReplaced] = lastAddress;

                        supportedTokens.pop();
                    }
                }
            }
        } else {
            if (tipAndTiers[_tokenAddress].length == 0) {
                // Push to array for new supported tokens
                supportedTokensIndex[_tokenAddress] = supportedTokens.length;
                supportedTokens.push(_tokenAddress);
            }
            require(_tipAndTiersSize >= 2, "6");
            require(_tipAndTiersSize <= 10, "1");
            for (uint256 i = 0; i < _tipAndTiersSize; i++) {
                require(_tipAndTiers[i] > 0, "2");
            }

            tipAndTiers[_tokenAddress] = _tipAndTiers;
        }
    }

    // @notice Save the unique addresses of the questioners
    function addQuestioner() private {
        // Only push a new address into the array if it does NOT contain
        // the selected address
        if (msg.sender != address(0) && questionersIndex[msg.sender] == 0) {
            // The min. value for the length of the array is 1, because
            // index 0 of the array always contains address(0)
            questionersIndex[msg.sender] = questioners.length;
            // Append the questioner to the questioners array
            questioners.push(msg.sender);
        }
    }

    /* ---------- PRIMARY FUNCTIONS ---------- */

    // @notice Ask a question to the RESPONDER
    // @param _digest The digest output of hash function in hex with prepended '0x'
    // @param _hashFunction The hash function code for the function used
    // @param _size The length of digest
    // @param _tierIndex The index of the selected tier in the tiers array
    function ask(
        address _tokenAddress,
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _tierIndex
    ) external payable notOwner {
        require(_tierIndex != 0, "7");
        uint256[] memory _tipAndTiers = tipAndTiers[_tokenAddress];
        require(_tierIndex < _tipAndTiers.length, "8");
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            require(msg.value == _tipAndTiers[_tierIndex], "9");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(_tipAndTiers.length != 0, "10");
            // Token storage _token = tokens[tokensLookup[_tokenAddress]];
            IERC20 _token = IERC20(_tokenAddress);
            // Deposit tokens
            require(
                _token.transferFrom(
                    msg.sender,
                    address(this),
                    _tipAndTiers[_tierIndex]
                ),
                "11"
            );
        }

        // Save new questioners
        addQuestioner();

        // Create Cid object from argumets
        Cid memory _question = Cid({
            digest: _digest,
            hashFunction: _hashFunction,
            size: _size
        });

        // Initialize answer object with default values
        Cid memory _answer;

        // Initialize the exchange object
        exchanges[msg.sender].push(
            Exchange({
                question: _question,
                answer: _answer,
                tokenAddress: _tokenAddress,
                balance: _tipAndTiers[_tierIndex],
                exchangeIndex: exchanges[msg.sender].length,
                tips: 0
            })
        );
    }

    // @notice The questioner or the responder can remove a question and
    // a refund is issued
    // TODO: Maybe have the responder receive a fraction of the refund if the
    // questioner removes the question
    function removeQuestion(address _questioner, uint256 _exchangeIndex)
        external
        noReentrant
    {
        // Only allow the owner to remove questions from any questioner
        address questioner;
        if (msg.sender == owner) {
            questioner = _questioner;
        } else {
            questioner = msg.sender;
        }

        // Get all the exchanges from a questioner
        Exchange[] storage _exchanges = exchanges[questioner];

        // Stop execution if the questioner has no questions
        require(_exchanges.length > 0, "12");

        // Check that the question exists
        require(_exchangeIndex < _exchanges.length, "13");

        // Check that the question has not been answered
        // An empty string is the default value for a string
        require(
            keccak256(bytes(_exchanges[_exchangeIndex].answer.digest)) ==
                keccak256(bytes("")),
            "14"
        );

        // Create a refund variable to return the money deposited
        uint256 refund = _exchanges[_exchangeIndex].balance;

        address _tokenAddress = _exchanges[_exchangeIndex].tokenAddress;
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            // Issue refund
            (bool success, ) = questioner.call{value: refund}("");
            require(success, "15");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(tipAndTiers[_tokenAddress].length != 0, "10");
            // Token storage _token = tokens[tokensLookup[_tokenAddress]];
            IERC20 _token = IERC20(_tokenAddress);
            // Deposit tokens
            // Pay the questioner
            require(_token.transfer(questioner, refund), "11");
        }

        if (_exchanges.length == 1) {
            // In this case, the questioner is removing their last question
            // 1- Remove his address from the questioners array
            // 2- Reset questionersIndex (default value of uint is 0)
            // 3- Remove the last exchange from the exchanges array

            // 0xabc is calling the function

            // [0x0, 0xabc, 0x123]
            // 0xabc -> 1
            // 0x123 -> 2

            // Get the last questioner in the array
            address lastQuestioner = questioners[questioners.length - 1];

            // Get the index for the function caller
            uint256 callerIndex = questionersIndex[questioner];

            // Change the index to that of the questioner to be deleted
            questionersIndex[lastQuestioner] = callerIndex;

            // [0x0, 0xabc, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Use the last questioner to overwrite the questioner to be deleted
            questioners[callerIndex] = lastQuestioner;

            // [0x0, 0x123, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Remove the last element/duplicate
            questioners.pop();

            // [0x0, 0x123]
            // 0xabc -> 1
            // 0x123 -> 1

            // Set questionersIndex to the default value: 0
            questionersIndex[questioner] = 0;

            // [0x0, 0x123]
            // 0xabc -> 0
            // 0x123 -> 1

            // Remove the last element
            // TODO: Check if the delete keyword should be used here
            _exchanges.pop();
        } else {
            // Delete question and shrink array

            // Get the last element of the array
            Exchange memory lastExchange = _exchanges[_exchanges.length - 1];

            // Change its exchangeIndex value to match new index
            lastExchange.exchangeIndex = _exchangeIndex;

            // Use the last element to overwrite the element to be deleted
            _exchanges[_exchangeIndex] = lastExchange;

            // Remove the last element/duplicate
            _exchanges.pop();
        }
    }

    // @notice The owner answers a question
    // @param _questioner The address which asked the question
    // @param _digest The digest output of hash function in hex with prepended '0x'
    // @param _hashFunction The hash function code for the function used
    // @param _size The length of digest
    // @param _exchangeIndex The index of the selected exchange in the array of exchanges of
    // the questioner
    function respond(
        address _questioner,
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _exchangeIndex
    ) external noReentrant onlyOwner {
        // Get all the exchanges from a questioner
        Exchange[] storage _exchanges = exchanges[_questioner];

        // Check that the exchange exists
        require(_exchangeIndex < _exchanges.length, "16");

        // Get the balance of the selected exchange
        uint256 _balance = _exchanges[_exchangeIndex].balance;

        // Create payment variables
        uint256 devFee = (_balance) / fee;
        uint256 payment = _balance - devFee;

        address _tokenAddress = _exchanges[_exchangeIndex].tokenAddress;
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            // Pay the owner of the contract (The Responder)
            (bool success, ) = owner.call{value: payment}("");
            require(success, "15");
            // Pay dev fee
            (bool devSuccess, ) = dev.call{value: devFee}("");
            require(devSuccess, "15");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(tipAndTiers[_tokenAddress].length != 0, "10");

            IERC20 _token = IERC20(_tokenAddress);

            // Pay the owner of the contract (The Responder)
            require(_token.transfer(owner, payment), "11");
            require(_token.transfer(dev, devFee), "11");
        }

        Cid memory _answer = Cid({
            digest: _digest,
            hashFunction: _hashFunction,
            size: _size
        });

        // Get the selected exchange
        Exchange memory _exchange = _exchanges[_exchangeIndex];

        // Update the selected exchange
        _exchange.answer = _answer;
        _exchange.balance = 0;

        _exchanges[_exchangeIndex] = _exchange;

        emit QuestionAnswered(_questioner, _exchangeIndex);
    }

    // @notice Tip an exchange to highlight helpful content
    function issueTip(address _questioner, uint256 _exchangeIndex)
        external
        payable
        notOwner
        noReentrant
    {
        // Get all the exchanges from a questioner
        Exchange[] storage _exchanges = exchanges[_questioner];

        // Check that the exchange exists
        require(_exchangeIndex < _exchanges.length, "16");

        // Pay the owner of the contract (The Responder)
        // TODO: Split the tip among the responder, the questioner and the dev
        address _tokenAddress = _exchanges[_exchangeIndex].tokenAddress;
        uint256 _tip = tipAndTiers[_tokenAddress][0];
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            // Check that the tip amount is correct
            require(msg.value == _tip, "17");
            (bool success, ) = owner.call{value: msg.value}("");
            require(success, "15");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(tipAndTiers[_tokenAddress][0] > 0, "10");
            // Token storage _token = tokens[tipAndTiers[_tokenAddress]];
            IERC20 _token = IERC20(_tokenAddress);

            require(_token.transferFrom(msg.sender, owner, _tip), "11");
        }

        // Get the selected exchange
        Exchange memory _exchange = _exchanges[_exchangeIndex];

        // Increment the tip count
        _exchange.tips = _exchanges[_exchangeIndex].tips + 1;

        // Update the selected exchange
        _exchanges[_exchangeIndex] = _exchange;

        // emit TipIssued(msg.sender, _questioner, _exchangeIndex);
    }
}
