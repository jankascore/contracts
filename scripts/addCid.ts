import {config} from 'dotenv';
import {JankaProtocol} from '../typechain-types/contracts/JankaProtocol'
import jankaJson from '../artifacts/contracts/JankaProtocol.sol/JankaProtocol.json'
import {Contract, ethers} from 'ethers';
config();

const baseAddress = "0x586981dEB8995848C003Bca567207052A3314a14"
const base = new ethers.providers.JsonRpcProvider('https://goerli.base.org')
const baseWallet = new ethers.Wallet(process.env.PRIVATE_KEY!, base)
const baseJanka = new ethers.Contract(baseAddress, jankaJson.abi, baseWallet) as JankaProtocol & Contract

const goerliAddress = "0x6833A38f5E2fF3E2e23Da5337Bb696d5b738495F"
const goerli = new ethers.providers.AlchemyProvider('goerli', process.env.ALCHEMY_KEY!)
const goerliWallet = new ethers.Wallet(process.env.PRIVATE_KEY!, goerli)
const goerliJanka = new ethers.Contract(goerliAddress, jankaJson.abi, goerliWallet) as JankaProtocol & Contract

const cid = 'QmRNYZMjkZmwh2fYYLWHCM4AwaMqsFCYSGeokXtxcEnSWJ';

const setCid = async (cid: string) => {
	try {
		console.log("Setting CID on Base");
		const tx1 = await baseJanka.allowAlgorithmCID(cid);
		const resp1 = await tx1.wait();

		console.log("Setting CID on Goerli");
		const tx2 = await goerliJanka.allowAlgorithmCID(cid);
		const resp2 = await tx2.wait();
	} catch (e) {
		console.log(JSON.stringify(e, undefined, 2))
	}
}

setCid(cid);