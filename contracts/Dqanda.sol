//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract DqandaFactory {
    Dqanda[] public dqandas;

    function create(uint256 _price) public {
        Dqanda newDqanda = new Dqanda(msg.sender, _price);
        dqandas.push(newDqanda);
    }
}

// RESPONDER: The owner of the contract.
// QUESTIONER: Anyone who asks a question.
contract Dqanda {
    address public owner;
    // The price in wei required to ask a question
    uint256 public price; // This will become a mapping of price tiers

    constructor(address _owner, uint256 _price) {
        owner = _owner;
        price = _price;

        // Occupy the first index
        questioners.push(address(0));
    }

    // Make the contract payable
    receive() external payable {}

    event QuestionAsked(address _questioner, uint256 _qIndex);
    event QuestionAnswered(address _questioner, uint256 _qIndex);
    event QuestionRemoved(address _questioner, uint256 _qIndex);

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy.");
        locked = true;
        _;
        locked = false;
    }

    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    struct Question {
        Cid question;
        Cid answer;
        uint256 qIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
    }

    // Questioners can ask multiple questions
    mapping(address => Question[]) internal questionsMapping;

    // Helper function to get all of the questions made by
    // a questioner
    function getQuestions(address _questioner)
        public
        view
        returns (Question[] memory)
    {
        return questionsMapping[_questioner];
    }

    // Indices from the questioners array
    // This is used to modify the questioners array
    mapping(address => uint256) internal questionersIndex;

    // An array of all questioners. Needed for the UI.
    address[] internal questioners;

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

    // Helper function to get the complete questioners array.
    function getQuestioners() public view returns (address[] memory) {
        return questioners;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Must be owner.");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Unauthorized: Must not be owner.");
        _;
    }

    // Ensure the questioner is paying the right price
    modifier coversCost() {
        require(msg.value == price, "Payment is not equal to the price.");
        _;
    }

    // Anyone, but the owner can ask a questions
    function ask(
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size
    ) public payable notOwner coversCost {
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

        uint256 qIndex = questionsMapping[msg.sender].length;

        // Initialize the question object
        questionsMapping[msg.sender].push(
            Question({
                question: _question,
                answer: _answer,
                balance: msg.value,
                qIndex: qIndex
            })
        );

        emit QuestionAsked(msg.sender, qIndex);
    }

    // Todo: Add option to pay removal fee to the responder
    // Remove a question and widthdraw funds
    function removeQuestion(uint256 _qIndex) public noReentrant {
        // Get all the questions from a questioner
        Question[] storage questions = questionsMapping[msg.sender];

        // Stop execution if the questioner has no questions
        require(questions.length > 0, "No questions available to remove.");

        // Check that the question exists
        require(_qIndex < questions.length, "Question does not exist.");

        // Check that the question has not been answered
        // An empty string is the default value for a string
        require(
            keccak256(bytes(questions[_qIndex].answer.digest)) ==
                keccak256(bytes("")),
            "Question already answered."
        );

        // Create a payment variable with the payment amount
        uint256 payment = questions[_qIndex].balance;

        if (questions.length == 1) {
            // In this case, the questioner is removing their last question
            // 1- Remove his address from the questioners array
            // 2- Reset questionersIndex (default value of uint is 0)
            // 3- Remove the last question from the questions array

            // 0xabc is calling the function

            // [0x0, 0xabc, 0x123]
            // 0xabc -> 1
            // 0x123 -> 2

            // Get the last questioner in the array
            address lastQuestioner = questioners[questioners.length - 1];

            // Get the index for the function caller
            uint256 callerIndex = questionersIndex[msg.sender];

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
            questionersIndex[msg.sender] = 0;

            // [0x0, 0x123]
            // 0xabc -> 0
            // 0x123 -> 1

            // If there is only one element,
            // just remove the last element
            questions.pop();
        } else {
            // Delete question and shrink array

            // Get the last element of the array
            Question memory lastQuestion = questions[questions.length - 1];

            // Change its qIndex value to match new index
            lastQuestion.qIndex = _qIndex;

            // Use the last element to overwrite the element to be deleted
            questions[_qIndex] = lastQuestion;

            // Remove the last element/duplicate
            questions.pop();
        }

        // Pay the questioner
        (bool success, ) = msg.sender.call{value: payment}("");
        require(success, "Failed to send Ether");

        emit QuestionRemoved(msg.sender, _qIndex);
    }

    // Only the owner can respond and get paid.
    function respond(
        address _questioner,
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _qIndex
    ) public noReentrant onlyOwner {
        // Get all the questions from a questioner
        Question[] storage questions = questionsMapping[_questioner];

        // Check that the question exists
        require(_qIndex < questions.length, "Question does not exist.");

        // Create payment variable
        uint256 payment = questions[_qIndex].balance;

        Cid memory _answer = Cid({
            digest: _digest,
            hashFunction: _hashFunction,
            size: _size
        });

        // Update one question based on the index
        questions[_qIndex] = Question({
            question: questions[_qIndex].question,
            answer: _answer,
            balance: 0 wei,
            qIndex: _qIndex
        });

        // Pay the owner of the contract (The Responder)
        (bool success, ) = owner.call{value: payment}("");
        require(success, "Failed to send Ether");

        emit QuestionAnswered(_questioner, _qIndex);
    }
}
