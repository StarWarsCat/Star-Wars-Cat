# contract project

### install nodejs
[Node.js](https://nodejs.org/en/)


## using with hardhat

### install hardhat (unnecessary)
[Hardhat | Ethereum development environment for professionals by Nomic Labs](https://hardhat.org/)
```shell script
$ npm install --save-dev hardhat
$ npx hardhat
```

### install hardhat-upgrades plugin (unnecessary)
[Hardhat | Ethereum development environment for professionals by Nomic Labs](https://hardhat.org/)
```shell script
$ npm install --save-dev @openzeppelin/hardhat-upgrades
```

### edit hardhat.config.js adding follow
```js
// hardhat upgrade plugins
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
```

### install pkg
```shell script
$ npm install
```

### edit config
`hardhat.config.js`  
`.env.js`  
`.secret.js`

### compile contract
```shell script
$ node cli.js c
$ node cli.js call // clean & compile
```

### deploy contract
```shell script
$ node cli.js d [deployNFTMetadata] -n localhost
```

### upgrade contract
```shell script
$ node cli.js u <./scripts/upgrade_V20210827.js> -n localhost
```

### run hardhat script
```shell script
$ node cli.js run <scripts/deploy_upgradeable.js> --network localhost
```


## using with truffle

### install truffle
[Truffle | Truffle Suite](https://www.trufflesuite.com/truffle)

### install pkg
```shell script
$ npm install
```

### edit config
`truffle-config.js`  
`.env.js`  
`.secret.js`  

### compile contract
```shell script
$ node ./ctl.js c
```

### deploy contract
```shell script
$ node ./ctl.js d <network> [deploy_function]
```
