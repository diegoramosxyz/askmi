//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// TODO: Make the answers updatable
// RESPONDER: The owner of the contract.
// QUESTIONER: Anyone who asks a question.
// EXCHANGE: The exchange between the questioner asking
// as question and the responder answering
contract AskMi {
    /** 
        VARIABLES
     */

    address public owner;
    // The tip cost in wei
    uint256 public tip;
    // address of the developer
    address internal dev;
    // dev fee (balance/200 = 0.5%)
    uint256 public fee = 200;
    // The prices in wei required to ask a question
    uint256[] internal tiers;
    // Questioners can have multiple exchanges with the same contract
    mapping(address => Exchange[]) internal exchanges;
    // Indices from the questioners array
    // This is used to modify the questioners array
    mapping(address => uint256) internal questionersIndex;
    // An array of all questioners
    address[] internal questioners;
    // Used to re-entrancy
    bool internal locked;

    /**
        CONSTRUCTOR
     */

    constructor(
        address _owner,
        uint256[] memory _tiers,
        uint256 _tip,
        address _dev
    ) {
        owner = _owner;
        tiers = _tiers;
        tip = _tip;
        dev = _dev;

        // Occupy the first index
        questioners.push(address(0));
    }

    // Make the contract payable
    receive() external payable {}

    /**
        STRUCTS
     */

    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    struct Exchange {
        Cid question;
        Cid answer;
        uint256 exchangeIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
        uint256 tips;
    }

    /**
        EVENTS
     */

    event QuestionAsked(address _questioner, uint256 _exchangeIndex);
    event QuestionAnswered(address _questioner, uint256 _exchangeIndex);
    event QuestionRemoved(address _questioner, uint256 _exchangeIndex);
    event TipIssued(
        address _tipper,
        address _questioner,
        uint256 _exchangeIndex
    );
    event TipUpdated(uint256 _newTipPrice);
    event TiersUpdated(uint256[] _newTiers);

    /** 
        MODIFIERS
     */

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Must be owner.");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Unauthorized: Must not be owner.");
        _;
    }

    // Ensure the questioner is paying the right price
    modifier coversCost(uint256 _tierIndex) {
        require(_tierIndex < tiers.length, "The selected tier does not exist.");
        require(
            msg.value == tiers[_tierIndex],
            "The deposit is not equal to the tier price."
        );
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy.");
        locked = true;
        _;
        locked = false;
    }

    /** 
        UPDATE FUNCTIONS 
    */

    function updateTip(uint256 _newTipPrice) public onlyOwner {
        tip = _newTipPrice;
        emit TipUpdated(_newTipPrice);
    }

    function updateTiers(uint256[] memory _newTiers) public onlyOwner {
        tiers = _newTiers;
        emit TiersUpdated(_newTiers);
    }

    /**
        GETTER FUNCTIONS
     */

    function getTiers() public view returns (uint256[] memory) {
        return tiers;
    }

    // Helper function to get the complete questioners array.
    function getQuestioners() public view returns (address[] memory) {
        return questioners;
    }

    // Helper function to get all of the questions asked by
    // one questioner
    function getQuestions(address _questioner)
        public
        view
        returns (Exchange[] memory)
    {
        return exchanges[_questioner];
    }

    /**
        HELPER FUNCTIONS
     */

    // Save new questioners
    function addQuestioner() internal {
        // If the questioner does not exist. 0 is the default value for uint256.
        if (msg.sender != address(0) && questionersIndex[msg.sender] == 0) {
            // Save the index on the questionersIndex mapping
            questionersIndex[msg.sender] = questioners.length;
            // Append the questioner to the questioners array
            questioners.push(msg.sender);
        }
    }

    function selectToRemove(address _questioner)
        internal
        view
        returns (address)
    {
        if (msg.sender == owner) {
            return _questioner;
        } else {
            return msg.sender;
        }
    }

    /**
        PRIMARY FUNCTIONS
     */

    // Anyone, but the owner can ask a questions
    function ask(
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _tierIndex
    ) public payable notOwner coversCost(_tierIndex) {
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

        uint256 _exchangeIndex = exchanges[msg.sender].length;

        // Initialize the exchange object
        exchanges[msg.sender].push(
            Exchange({
                question: _question,
                answer: _answer,
                balance: msg.value,
                exchangeIndex: _exchangeIndex,
                tips: 0
            })
        );

        emit QuestionAsked(msg.sender, _exchangeIndex);
    }

    // The questioner can remove its own questions and receive a refund
    // The owner can reject the question and issue a refund
    function removeQuestion(address _questioner, uint256 _exchangeIndex)
        public
        noReentrant
    {
        // Only allow the owner to remove questions from any questioner
        address questioner = selectToRemove(_questioner);

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

            // If there is only one element,
            // just remove the last element
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

        // Pay the questioner
        (bool success, ) = questioner.call{value: refund}("");
        require(success, "Failed to send Ether");

        emit QuestionRemoved(questioner, _exchangeIndex);
    }

    // Only the owner can respond and get paid.
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

        uint256 _balance = _exchanges[_exchangeIndex].balance;

        // Create payment variables
        // Dev fee (0.5%)
        uint256 devFee = (_balance) / fee;
        uint256 ownerPayment = _balance - devFee;

        Cid memory _answer = Cid({
            digest: _digest,
            hashFunction: _hashFunction,
            size: _size
        });

        Exchange storage _exchange = _exchanges[_exchangeIndex];

        // Update the selected exchange
        _exchange.answer = _answer;
        _exchange.balance = 0 wei;

        // Update one exchange based on the index
        _exchanges[_exchangeIndex] = _exchange;

        // Pay the owner of the contract (The Responder)
        (bool success, ) = owner.call{value: ownerPayment}("");
        require(success, "Failed to send Ether");
        // Pay dev fee
        (bool devSuccess, ) = dev.call{value: devFee}("");
        require(devSuccess, "Failed to send Ether");

        emit QuestionAnswered(_questioner, _exchangeIndex);
    }

    // Tip an exchange
    function issueTip(address _questioner, uint256 _exchangeIndex)
        public
        payable
        notOwner
    {
        // Get all the exchanges from a questioner
        Exchange[] storage _exchanges = exchanges[_questioner];

        // Check that the exchange exists
        require(_exchangeIndex < _exchanges.length, "Exchange does not exist.");

        // Check that the tip amount is correct
        require(msg.value == tip, "The tip amount is incorrect.");

        // Create payment variable
        uint256 payment = msg.value;

        Exchange storage _exchange = _exchanges[_exchangeIndex];

        _exchange.tips = _exchanges[_exchangeIndex].tips + 1;
        // Update the selected exchange
        _exchanges[_exchangeIndex] = _exchange;

        // Pay the owner of the contract (The Responder)
        (bool success, ) = owner.call{value: payment}("");
        require(success, "Failed to send Ether");

        emit TipIssued(msg.sender, _questioner, _exchangeIndex);
    }
}
