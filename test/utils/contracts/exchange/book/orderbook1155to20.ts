import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract, ContractTransaction } from "ethers";
import { ethers } from "hardhat";

export async function validateLimitOrder1155To20(
    orderBookName: string,
    signer: SignerWithAddress,
    fromTokenName: string,
    destTokenName: string,
    fromAmount: BigNumber,
    destAmount: BigNumber,
    limitPrice: BigNumber,
    makerOnly: boolean,
    takerOnly: boolean
) {

    //TODO: handle non-clean multiple of price
    const orderBook = hre.props[orderBookName];
    const fromToken = hre.props[fromTokenName];
    const destToken = hre.props[destTokenName];
    let fromDecimals; let destDecimals; let destTokenId; let fromTokenId;

    if(destTokenName == "token1155"){
        fromDecimals = await fromToken.decimals();
        destDecimals = 0;
        destTokenId = hre.props.token1155Id;
        fromTokenId = 0;
    }
    else if (destTokenName == "token20"){
        fromDecimals = 0;
        destDecimals = await destToken.decimals();
        destTokenId = 0;
        fromTokenId = hre.props.token1155Id;
    }
    const fromMultiplier = ethers.utils.parseUnits("1", fromDecimals + 18);
    const destMultiplier = ethers.utils.parseUnits("1", destDecimals + 18);

    if(makerOnly){
        const quoteBefore: [BigNumber, BigNumber] = await orderBook.quoteExactAmountOut(
            destToken.address,
            ethers.constants.MaxUint256.div(fromMultiplier),
            ethers.constants.MaxUint256
        );

        let firstPageBefore; let isBook0: boolean;

        if(fromToken.address == await orderBook.token20()){
            firstPageBefore = await orderBook.firstPageInBook0();
            isBook0 = true;
        } else if (fromToken.address == await orderBook.token1155()) {
            firstPageBefore = await orderBook.firstPageInBook1();
            isBook0 = false;
        }

        const firstPagePriceBefore = (await orderBook.pages(firstPageBefore)).price;
    
        let destAmountInBefore: BigNumber = quoteBefore[0];
        let fromAmountOutBefore: BigNumber = quoteBefore[1];

        // validate page keys
        const pageKey = await orderBook.getPageKey(
            destToken.address,
            destTokenId,
            destAmount,
            fromAmount
        );

        const pagePrice = await orderBook.getPagePrice(
            destToken.address,
            destTokenId,
            destAmount,
            fromAmount
        )

        const pageBefore = await orderBook.pages(pageKey);
        const currentOffsetBefore = await pageBefore.currentOffset;
        const orderBefore = await orderBook.orders(pageBefore.latestOrder)
        const lastOffsetBefore: BigNumber = orderBefore.endOffset;

        if(!lastOffsetBefore.eq(0))
            expect(orderBefore.page).to.equal(pageKey);

        await orderBook.connect(signer).limitOrder(
            fromToken.address,
            fromTokenId,
            fromAmount,
            destAmount,
            limitPrice,
            makerOnly,
            takerOnly
        );

        const pageAfter = await orderBook.pages(pageKey);
        const orderAfter = await orderBook.orders(pageAfter.latestOrder);
        const startOffsetAfter: BigNumber = orderAfter.startOffset;
        const lastOffsetAfter: BigNumber = orderAfter.endOffset;

        expect(pageAfter.currentOffset).to.equal(currentOffsetBefore);
        expect(startOffsetAfter).to.equal(lastOffsetBefore);
        expect(lastOffsetAfter.sub(lastOffsetBefore)).to.equal(fromAmount);
        expect(orderAfter.page).to.equal(pageKey);

        const quoteAfter: [BigNumber, BigNumber] = await orderBook.quoteExactAmountOut(
            destToken.address,
            ethers.constants.MaxUint256.div(fromMultiplier),
            ethers.constants.MaxUint256
        );

        let destAmountInAfter: BigNumber = quoteAfter[0];
        let fromAmountOutAfter: BigNumber = quoteAfter[1];

        //TODO: account for leftover erc-20 token

        expect(destAmountInAfter.sub(destAmountInBefore)).to.equal(destAmount);
        expect(fromAmountOutAfter.sub(fromAmountOutBefore)).to.equal(fromAmount);

        // check for change in first page based on page price
        if(pagePrice.lte(firstPagePriceBefore) || firstPagePriceBefore.eq(BigNumber.from("0"))){
            if(isBook0) expect(await orderBook.firstPageInBook0()).to.be.equal(pageKey);
            else        expect(await orderBook.firstPageInBook1()).to.be.equal(pageKey);
        }
        else {
            if(isBook0) expect(await orderBook.firstPageInBook0()).to.be.equal(firstPageBefore);
            else        expect(await orderBook.firstPageInBook1()).to.be.equal(firstPageBefore);
        }
    }

    else if(takerOnly){
        const quoteBefore: [BigNumber, BigNumber] = await orderBook.quoteExactAmountOut(
            fromToken.address,
            ethers.constants.MaxUint256.div(destMultiplier),
            limitPrice
        );
        let fromAmountInBefore: BigNumber = quoteBefore[0];
        let destAmountOutBefore: BigNumber = quoteBefore[1];

        if(fromAmountInBefore < fromAmount){
            fromAmount = fromAmountInBefore;
        }
        if(destAmountOutBefore < destAmount) {
            destAmount = destAmountOutBefore;
        }

        await orderBook.connect(signer).limitOrder(
            fromToken.address,
            fromTokenId,
            fromAmount,
            destAmount,
            limitPrice,
            makerOnly,
            takerOnly
        );

        const quoteAfter: [BigNumber, BigNumber] = await orderBook.quoteExactAmountOut(
            fromToken.address,
            ethers.constants.MaxUint256.div(destMultiplier),
            ethers.constants.MaxUint256
        );

        let fromAmountInAfter: BigNumber = quoteAfter[0];
        let destAmountOutAfter: BigNumber = quoteAfter[1];

        expect(fromAmountInBefore.sub(fromAmountInAfter)).to.equal(fromAmount);
        expect(destAmountOutBefore.sub(destAmountOutAfter)).to.equal(destAmount);

        // TODO: quote every page up to the limitPrice to calculate key firstPageAfter
        // TODO: check each completely filled page currentOffset is lastOrder.endOffset
        // TODO: check partially filled page currentOffset accounting for cancels
    }

}