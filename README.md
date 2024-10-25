# laxce-contracts

## Deployment
### Create a env file as below in root folder
```file
RPC_URL="",
PRIVATE_KEY="",
ETHERSCAN_API_KEY=""
```

### Deploying Contracts
Deploy Contracts, change the value for network accordingly
* mainnet
```cmd
npx hardhat run scripts/deploy.js --network mainnet
```
### Verifying Contracts
Replace the address with the specific contract addresses address that automatically verify and link the proxy contract

```cmd
npx hardhat verify --network mainnet <DEPLOYED_CONTRACT_ADDRESS>
```