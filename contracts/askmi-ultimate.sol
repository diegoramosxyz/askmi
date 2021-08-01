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

// @title A question-and-answer smart contract
// @author Diego Ramos
contract AskMiUltimate {
    /** ---------- STRUCTS ---------- */

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
    }

    /** ---------- VARIABLES ---------- */

    // @notice Find a token and its data using its address
    mapping(address => uint256[]) internal tiers;

    // @notice The owner of this smart contract
    address public owner;

    // @notice The developer's address which receives the dev fee
    address internal dev;

    // @notice The fee sent to the developer (balance/200 = 0.5%)
    uint256 public fee = 200;

    // @notice The list of questions from a questioner
    mapping(address => Exchange[]) internal exchanges;

    // @notice Helper mapping to find specific questioners
    // This is used to modify the questioners array
    mapping(address => uint256) internal questionersIndex;

    // @notice An array of all unique addresses which have asked a question
    address[] internal questioners;

    // @notice Variable used to prevent re-entrancy
    bool internal locked;

    /** ---------- CONSTRUCTOR ---------- */

    // @param _dev The developer's address which receives the dev fee
    // @param _owner The owner of the current contract
    // @param _tiers The prices to ask a question
    constructor(
        address _dev,
        address _owner,
        uint256[] memory _tiers
    ) {
        uint256 _tiersSize = _tiers.length;
        require(_tiersSize >= 1, "There must be at least one tier.");
        for (uint256 i = 0; i < _tiersSize; i++) {
            require(_tiers[i] > 0, "The tier price must be greater than 0.");
        }

        dev = _dev;
        owner = _owner;

        // Save default tiers
        tiers[address(0)] = _tiers;

        // Occupy the first index
        questioners.push(address(0));
    }

    // Make the smart contract payable
    receive() external payable {}

    /** ---------- EVENTS ---------- */

    event QuestionAnswered(address _questioner, uint256 _exchangeIndex);

    /** ---------- MODIFIERS ---------- */

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Must be owner.");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Unauthorized: Must not be owner.");
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy.");
        locked = true;
        _;
        locked = false;
    }

    /** ---------- GETTER FUNCTIONS ---------- */

    // @notice Get the complete tiers array
    function getTiers(address _tokenAddress)
        public
        view
        returns (uint256[] memory)
    {
        return tiers[_tokenAddress];
    }

    // @notice Get the complete questioners array.
    function getQuestioners() public view returns (address[] memory) {
        return questioners;
    }

    // @notice Get all of the questions asked by one questioner
    function getQuestions(address _questioner)
        public
        view
        returns (Exchange[] memory)
    {
        return exchanges[_questioner];
    }

    /** ---------- UPDATE FUNCTIONS ---------- */

    // @notice Update the tiers array
    function updateTiers(address _tokenAddress, uint256[] memory _newTiers)
        public
        onlyOwner
    {
        uint256 _tiersSize = _newTiers.length;

        require(_tiersSize >= 1, "There must be at least one tier.");
        // Not bounded for loop. It could theoretically become so big it runs
        // out of gas. That would be the owners fault only.
        for (uint256 i = 0; i < _tiersSize; i++) {
            require(_newTiers[i] > 0, "The tier price must be greater than 0.");
        }

        tiers[_tokenAddress] = _newTiers;
    }

    /** ---------- HELPER FUNCTIONS ---------- */

    // @notice Save the unique addresses of the questioners
    function addQuestioner() internal {
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

    /** ---------- PRIMARY FUNCTIONS ---------- */

    function addERC20(address _tokenAddress, uint256[] memory _tiers)
        public
        onlyOwner
    {
        // Check that the token hasn't been added
        require(
            tiers[_tokenAddress].length == 0 && _tokenAddress != address(0),
            "This ERC20 has already been added."
        );

        tiers[_tokenAddress] = _tiers;
    }

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
    ) public payable notOwner {
        uint256[] memory _tiers = tiers[_tokenAddress];
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            require(
                _tierIndex < _tiers.length,
                "The selected tier does not exist."
            );
            require(
                msg.value == _tiers[_tierIndex],
                "The deposit is not equal to the tier price."
            );
        } else {
            // Check that the ERC20 exists in the lookup table
            require(_tiers.length != 0, "This token is not supported.");
            // Token storage _token = tokens[tokensLookup[_tokenAddress]];
            IERC20 _token = IERC20(_tokenAddress);
            // Deposit tokens
            require(
                _token.transferFrom(
                    msg.sender,
                    address(this),
                    _tiers[_tierIndex]
                ),
                "Error transfering funds."
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
                balance: _tiers[_tierIndex],
                exchangeIndex: exchanges[msg.sender].length
            })
        );
    }

    // @notice The questioner or the responder can remove a question and
    // a refund is issued
    // TODO: Maybe have the responder receive a fraction of the refund if the
    // questioner removes the question
    function removeQuestion(address _questioner, uint256 _exchangeIndex)
        public
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
        require(_exchanges.length > 0, "No questions available to remove.");

        // Check that the question exists
        require(_exchangeIndex < _exchanges.length, "Question does not exist.");

        // Check that the question has not been answered
        // An empty string is the default value for a string
        require(
            keccak256(bytes(_exchanges[_exchangeIndex].answer.digest)) ==
                keccak256(bytes("")),
            "Question already answered."
        );

        // Create a refund variable to return the money deposited
        uint256 refund = _exchanges[_exchangeIndex].balance;

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

        address _tokenAddress = _exchanges[_exchangeIndex].tokenAddress;
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            // Issue refund
            (bool success, ) = questioner.call{value: refund}("");
            require(success, "Failed to send Ether");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(
                tiers[_tokenAddress].length != 0,
                "This token is not supported."
            );
            // Token storage _token = tokens[tokensLookup[_tokenAddress]];
            IERC20 _token = IERC20(_tokenAddress);
            // Deposit tokens
            // Pay the questioner
            require(
                _token.transfer(questioner, refund),
                "Failed to send issue refund."
            );
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
    ) public noReentrant onlyOwner {
        // Get all the exchanges from a questioner
        Exchange[] storage _exchanges = exchanges[_questioner];

        // Check that the exchange exists
        require(_exchangeIndex < _exchanges.length, "Exchange does not exist.");

        // Get the balance of the selected exchange
        uint256 _balance = _exchanges[_exchangeIndex].balance;

        // Create payment variables
        uint256 devFee = (_balance) / fee;
        uint256 payment = _balance - devFee;

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

        address _tokenAddress = _exchanges[_exchangeIndex].tokenAddress;
        // If _tokenAddress is the 0 address, this is an ETH transaction
        if (_tokenAddress == address(0)) {
            // Pay the owner of the contract (The Responder)
            (bool success, ) = owner.call{value: payment}("");
            require(success, "Failed to send Ether");
            // Pay dev fee
            (bool devSuccess, ) = dev.call{value: devFee}("");
            require(devSuccess, "Failed to send Ether");
        } else {
            // Check that the ERC20 exists in the lookup table
            require(
                tiers[_tokenAddress].length != 0,
                "This token is not supported."
            );

            IERC20 _token = IERC20(_tokenAddress);

            // Pay the owner of the contract (The Responder)
            require(_token.transfer(owner, payment), "Failed to pay owner.");
            require(_token.transfer(dev, devFee), "Failed to pay developer.");
        }

        emit QuestionAnswered(_questioner, _exchangeIndex);
    }
}
