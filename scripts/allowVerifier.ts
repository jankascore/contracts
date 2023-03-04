import fs from 'fs';
import {config} from 'dotenv';
import {JankaProtocol} from '../typechain-types/contracts/JankaProtocol'
import jankaJson from '../artifacts/contracts/JankaProtocol.sol/JankaProtocol.json'
import {Contract, ethers} from 'ethers';
config();

const address = "0x6833A38f5E2fF3E2e23Da5337Bb696d5b738495F"
const provider = new ethers.providers.AlchemyProvider('goerli', process.env.ALCHEMY_KEY!)
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider)
const janka = new ethers.Contract(address, jankaJson.abi, wallet) as JankaProtocol & Contract

const verifier = '0x99762cf0e09e8948d417cac0a17df952c2a83b5d';

const setVerifier = async (address: string) => {
	const tx = await janka.allowVerifier(address);
	const resp = await tx.wait();
}

setVerifier(verifier);