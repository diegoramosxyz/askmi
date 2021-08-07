# Gas stats

Asuming a 0.000000017 ETH / 17 Gwei Gas price

`Execution Cost = Gas used * Gas Price`

## AskMi Factory

| Action           | Gas Used | Execution Cost in ETH |
| ---------------- | -------- | --------------------- |
| Deployment       | 3665329  | 0.0623                |
| instantiateAskMi | 2914211  | 0.0495                |

## AskMi Factory (ERC20)

| Action           | Gas Used | Execution Cost in ETH |
| ---------------- | -------- | --------------------- |
| instantiateAskMi | 3146450  | 0.0534                |

## AskMi Instance

| Action         | Gas Used | Execution Cost in ETH |
| -------------- | -------- | --------------------- |
| ask            | 272212   | 0.0046                |
| removeQuestion | 62929    | 0.0010                |
| respond        | 197852   | 0.0033                |
| updateTiers    | 46602    | 0.0008                |
| updateTip      | 30119    | 0.0005                |
| issueTip       | 96400    | 0.0016                |

## AskMi Instance (ERC20)

| Action         | Gas Used | Execution Cost in ETH |
| -------------- | -------- | --------------------- |
| ask            | 254768   | 0.0043                |
| removeQuestion | 77174    | 0.0013                |
| respond        | 75163    | 0.0013                |
| updateTiers    | 48932    | 0.0008                |
| updateTip      | 37850    | 0.0006                |
| issueTip       | 85319    | 0.0015                |
