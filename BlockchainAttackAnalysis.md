***\*智能合约安全常见攻击方式由浅入深分析（闪电贷攻击、重入攻击、操作预言机）\****

**目** **录**

[一、实验工具简介	](#_Toc171023938)

[1.1 hardhat	](#_Toc171023939)

[1.2 foundry	](#_Toc171023940)

[二、闪电贷攻击	](#_Toc171023941)

[2.1什么是闪电贷	](#_Toc171023942)

[2.2 什么是闪电贷攻击	](#_Toc171023943)

[2.3 闪电贷攻击案例分析	](#_Toc171023944)

[2.4 闪电贷攻击复现	](#_Toc171023945)

[三、重入攻击	](#_Toc171023946)

[3.1 什么是重入攻击	](#_Toc171023947)

[3.2重入攻击案例分析	](#_Toc171023948)

[3.3 重入攻击案例复现	](#_Toc171023949)

[四、操作预言机	](#_Toc171023950)

[4.1 什么是预言机	](#_Toc171023951)

[4.2 什么是操作预言机	](#_Toc171023952)

[4.3 操作预言机攻击案例分析	](#_Toc171023953)

[4.4 操作预言机攻击案例复现	](#_Toc171023954)

[五、过程中遇到的问题	](#_Toc171023955)

 

***\*F\*******\*oundry安装和使用：\****

1.安装foundry

1.1 确保你的系统已经安装了 rust。可以使用以下命令安装rust：

rustup update stable 

1.2 使用rust的包管理器cargo安装foundry：

cargo install --git https://github.com/foundry-rs/foundry --profile release --locked forge cast chisel anvil 

1.3 当然也可以使用docker进行安装：

-- docker pull ghcr.io/foundry-rs/foundry:latest 

-- docker build -t foundry 

1.4 创建初始项目

forge init hello_foundry 

2.配置foundry

2.1 在使用foundry之前，首先需要配置foundry.toml文件。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps8.jpg) 

2.2 可以选择性的配置remapping.txt文件。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps9.jpg) 

# 1.闪电贷攻击

## 1.1什么是闪电贷

闪电贷（flash loan）是一种无需抵押且即借即还的DeFi借贷模式。不同于传统的去中心化借贷平台如Compound，后者通常要求用户提供超额抵押（例如，为了借出75个虚拟代币，需提供100个虚拟代币作为抵押），闪电贷极大地提高了资金的利用率。用户通过智能合约在一个交易中完成借贷和还款，如果无法在同一交易中还款，之前的所有操作将被回滚，从而保证了合约的安全性和资金的安全。用户可在借贷与还款之间执行自定义逻辑，如进行套利，利用不同交易所之间的价格差异来赚取利润，并在交易结束时归还初始贷款。这种模式不仅减少了传统借贷所需的高额抵押成本，还为用户提供了执行复杂金融策略的灵活性，如套利或市场操纵等，而这一切均在区块链技术的支持下安全高效地完成。

为了保证闪电贷中一笔贷款可以在借出后，借贷人不会因为拒绝还款而违约，闪电贷在使用时，借款人必须在借款资金发放的同一个交易日偿还借款，而如果中间出现了还款余额不足，这个事务便会回滚之前的所有操作而不会被执行，保证了合约和资金的安全性，避免了可能的违约情况。

在实际的使用中，用户通过发布自己的智能合约，并在合约执行的开始和结束中调用闪电贷项目合约，加入借款与还款操作，并在借款与还款之间加入自己定制的逻辑，以实现不同的功能，比如套利，即利用不同去中心化交易所之间的价格差赚取差额利润，并在交易结束后归还初始贷款的行为。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps10.jpg) 

例上图，闪电贷整攻击整体逻辑解释如下：

(1)调用Flashloan功能 - 批准或转移交换费用

(2)请求代币数量 - 调用flashLoan()功能

(3)接收借入金额 - 执行receiveFlashLoan()功能

(4)执行所需逻辑 - 使用借来的flashloan金额执行tradeStrategy()

(5)偿还代币（及任何费用） - 将代币转回给借方/flashloan合约

(6)净（理论）利润 - 要求：套利交易利润 - 交换费 > 0

## 1.2 什么是闪电贷攻击

闪电贷是一种创新的DeFi应用，它利用智能合约的回滚机制，在单个交易中允许用户获取并使用大量资金后迅速归还，极大地降低了资金运作成本。闪电贷攻击则是利用这一特性，结合其他智能合约漏洞，对去中心化平台发起的攻击行为。这类攻击主要分为两种类型：一是基于询价机制的攻击，二是基于合约本身漏洞的攻击。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps11.jpg) 

***\*1、基于询价机制的闪电贷攻击。\****

在去中心化借贷、去中心化交易所中，虚拟货币之间的兑换汇率是通过特定的公式计算出来的，而通过进行大额交易会使得兑换汇率发生快速异常波动，这一特性便可以被利用来对过于单一的询价机制进行攻击，但这样的攻击需要大量的资金支持，所以很少有人能成功实施攻击。闪电贷的出现则大大降低了上述价格攻击的门槛，针对价格的闪电贷攻击可以大概分为四步即闪电贷借款、抵押、操纵价格、攻击收尾：

（1）闪电贷借款，攻击者首先通过闪电贷借出大量数额的资产，获得足够使资金池的价格发生剧烈变化的资产A以及准备存储攻击目标的资产B；

（2）抵押，攻击者将资产B抵押进攻击目标获得一定的资金池抵押物；

（3）操纵价格，攻击者使用资产A进行价格操纵，使资金池内的价格比例发生剧烈变动，攻击资产B的询价机制从而抬高资产B的抵押物估值；

（4）收尾，由于资产B对应的抵押物估值上升，用户将抵押物兑换回资产B并最后将闪电贷借款的本金进行归还，获利估值上升的差价。

***\*2、基于合约漏洞的闪电贷攻击。\****

在去中心化借贷、去中心化交易所中，如果出现某些可被利用的漏洞如常规错误、重入，攻击者虽然可以对其进行攻击，但由于自己攻击本金较少，通常获利也较少，而闪电贷这样的能在一个交易中获取大量资金的功能则放大了这样攻击所涉及的资金量，从而使得攻击者可以以很高的本金进行攻击，造成大额的损失。

闪电贷攻击的发生是由多种因素结合而成：

（1）闪电贷获得的超高的资金量为攻击提供了基础，它可以放大攻击的损失，降低攻击门槛；

（2）智能合约的漏洞或为攻击提供了利用基础；

（3）DeFi生态的去中心化业务缺乏对单个项目或多个项目共同的宏观调控与管控机制，则为攻击提供了利用背景。在这样的多种因素的共同作用之下，闪电贷攻击变得越来越多。

第一次基于闪电贷的价格攻击发生在2020年2月15日，攻击者在以太坊区块链高度9484688期间进行攻击，在bZx资金池内进行价格操纵，并最终获利1271.4个以太币，在当时价值35万美元。此后至2021年6月的一年多时间里，总共发生了20多次闪电贷攻击，涉及的代币价值从几万到几亿美元不等，造成了非常大的资金损失。

闪电贷功能出现至今，其攻击事件有着愈演愈烈的趋势，不但攻击频率逐渐上升，损失金额也不断上升，其原因有4点：

（1）闪电贷降低了价格攻击的门槛，使攻击者几乎不需要任何成本就可以攻击。

（2）闪电贷功能放大了攻击过程中的资金量，从而放大了攻击的损失。

（3）不同的项目之间存在严重的代码fork现象，以2021年5月24日及26日发生在BSC链上的AutoShark、Merlin闪电贷攻击为例，其代码全都fork自于5月20日发生闪电贷攻击的Bunny交易所，而其攻击方式、原理也几乎一摸一样，这样的DeFi现状导致一个交易所被发现漏洞，其攻击隐患可能会波及其它相同代码源头的交易所。

（4）去中心化金融应用体现在区块链上是一个个合约，而不同项目的合约之间的互相组合虽然可以让去中心化金融领域的应用深度和广度大大拓展，但在缺乏有效的风险管控情况下也会引入恶意或高风险的应用，降低了用户资金的安全性。

## 1.3 闪电贷攻击案例分析

***\*案例介绍：\****

2022年6月6日，Discover项目遭到闪电贷攻击，此次攻击中攻击者结合了闪电贷与预言机价格操纵，利用闪电贷借出的大量资金在去中心化交易池中进行交易，从而提高一种代币的价格，向属于基于询价机制的闪电贷攻击。可以理解为：

2022年6月6日， Discover项目遭到一次快速借贷（闪电贷）攻击。在此次攻击中，攻击者利用了快速借贷和预言机价格操纵的策略，借出了大量的资金用于市场（去中心化交易池pancakeSwap）中购买大批萝卜，从而推高萝卜的价格，这是一种基于询价机制的快速借贷攻击手法。

***\*整体攻击逻辑为：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps12.jpg) 

***\*PancakeSwap交易所：\****

交易池（如萝卜和白菜的交易池）通常是指自动化做市商（AMM）模型中的一个组成部分。这种模型常见于去中心化交易所（DEX），比如 Uniswap、PancakeSwap 等。以下是这种交易池如何维持萝卜和白菜之间价格平衡的基本原理：

***\*交易池的基础：\****

交易池本质上是一个包含两种代币（假设2个代币是萝卜和白菜）的智能合约。交易者可以与这个池子进行交互，执行买卖操作。交易池通过算法自动维持两种代币之间的价格平衡。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps13.jpg) 

***\*常用的AMM模型 — 常数乘积公式：\****

一个常见的自动化做市商模型是使用常数乘积公式 �� × �� = ��，其中 �� 和 �� 分别是交易池中两种代币的数量，而 �� 是一个常数。这个公式确保了池子的总价值在交易前后保持不变。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps14.png) 

 

***\*价格维持机制：\****

1）初始设定：假设一个交易池开始时含有相等价值的萝卜和白菜。比如，1000单位的萝卜和200单位的白菜，假设初始交换比率是 5 萝卜兑换 1 白菜。

2）交易影响：当用户想用萝卜换取白菜时，他们将萝卜添加到池中，并从池中取出相应数量的白菜。这会导致萝卜的数量增加，白菜的数量减少，从而根据公式 ��×��=��调整两者的价格。

3）因为萝卜的供应增加，相对价值下降；同时，白菜变得更稀缺，其价值上升。

4）价格自动调整：交易后，新的交换率会自动调整。比如，如果现在池中有1100单位的萝卜和180单位的白菜，新的交换率可能会变为 6.11 萝卜兑换 1 白菜，反映了萝卜相对白菜价值的下降。交换代币函数整体执行逻辑为：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps15.jpg) 

***\*攻击者相关信息\****：

攻击者钱包地址：0x446247bb10B77D1BCa4D4A396E014526D1ABA277

攻击者合约：0x06B912354B167848a4A608a56BC26C680DAD3D79

攻击交易：

0x8a33a1f8c7af372a9c81ede9e442114f0aabb537e5c3a22c0fd7231c4820f1e9

被攻击项目-ETHpledge合约：0x5908E4650bA07a9cf9ef9FD55854D4e1b700A267

攻击者获利：49BNB($27600)

***\*攻击流程：\****

1）攻击第一阶段：攻击者从市场（pancakeSwap交易所）中借来一大笔资金。

Step1： 第一笔借款是在西红柿兑白菜的交换池（BUSD代币-USDT代币的交换池）中借出2100个白菜（USDT代币，也就是BSC-USD，和美元一比一锚定，名字不同是因为设计原因），通过市场的交换功能（Pancake LP的swap函数）完成；

Step2： 第二笔借款是在萝卜兑白菜交换池（Discover代币-USDT代币的交换池）中借出19000个白菜 （USDT代币），通过在具有回调函数的合约中再次调用交换功能进行嵌套调用完成。具体借款流程如下所示：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps16.jpg) 

（https://app.blocksec.com/explorer/tx/bsc/0x8a33a1f8c7af372a9c81ede9e442114f0aabb537e5c3a22c0fd7231c4820f1e9）

2）攻击第二阶段：

攻击者通过制造价格差异来获得利润。关键在于攻击者在从ETHpledge项目中用白菜抵押得到萝卜（使用USDT代币购买Discover代币）时，ETHpledge项目中白菜价格依赖市场中的白菜价格（USDT代币）。由于攻击者通过前两次的快速借贷，借出了市场中大量的白菜（USDT代币），此时白菜（USDT代币）的价格会迅速升高，因此ETHpledge项目得到的白菜（USDT代币）价格偏高，其能换到的萝卜数量（Discover代币）也就偏多。攻击者用第一次借来的白菜（USDT代币）全部换成萝卜（Discover代币）。具体攻击流程如下图所示：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps17.jpg) 

Step3. 这个阶段，攻击者迅速归还数量较多的一笔白菜（USDT代币）快速借款（率先归还欠款较大的金额是因为为了抹平市场中USDT的上涨价格），使得市场中的白菜(USDT)价格恢复正常水平。至此，攻击者手握通过价格差价获得的大量萝卜（Discover代币）以及欠款一小部分白菜（USDT代币）。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps18.jpg) 

Step4. 攻击者通过市场（pancakeswap）的交换函数将自己得到的萝卜（discover代币）全部换成白菜（USDT代币），再向交易池归还快速白菜借贷（USDT代币），而余下的白菜（USDT代币）全归攻击者所有。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps19.jpg) 

Step5. 攻击者将套利获得的白菜换成BNB，然后转入混币项目，完成攻击。

## 1.4 闪电贷攻击复现

***\*F\*******\*oundry靶场复现流程：\****

Step1.foundry环境准备：

Step2.代码复现：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps20.jpg) 

我们在本地复现了Discover攻击的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，     我们编写了自己的攻击合约来复现整个交易流程：

我们将上述函数作为整个攻击交易的入口， 通过vm.startBroadcast()方法来将整个交易的发起者置为攻击者。接着我们调用PancakePairI中的swap函数闪电贷来第一笔资金2100USD，接着PancakePair中的swap回调pancakeCall函数：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps21.jpg) 

我们在pancakeCall函数中调用PancakePairII的swap函数，再次通过闪电贷借来一笔资金19000USD，由于进行了swap函数调用，PancakePairII会再次回调pancakeCall函数：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps22.jpg) 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps23.jpg) 

在此处代码中，模仿攻击者调用受害项目ethpledge中的pledgein函数，由于ethpledge是根据pancakePair中的USD数量来指定当前Discover代币的价格，由于，PancakePair中的USD进过两次闪电贷后，数量减少，所以Discover的价格降低，攻击者可以使用自己贷款出来的USD换取更多的Discover代币。    	所以攻击者将其转移到0xab21300fa507ab30d50c3a5d1cad617c19e83930，之后再将62000Discover从0xab21300fa507ab30d50c3a5d1cad617c19e83930转移到合约0x06B912354B167848a4A608a56BC26C680DAD3D79。

***\*合约调用时序图为：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps24.jpg) 

***\*H\*******\*ardhat靶场上复现攻击：\****

通过在bscscan（币安区块链游览器）查看到该攻击者账户地址是：0x446247bb10b77d1bca4d4a396e014526d1aba277。攻击者部署了2个智能合约作为攻击前的准备。

***\*攻击前的准备：\****

攻击者部署两个智能合约作为整个攻击的一环。

攻击者合约79地址-0x06b912354b167848a4a608a56bc26c680dad3d79： 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps25.jpg) 

攻击者合约30地址- 0xFa9c2157Cf3D8Cbfd54F6BEF7388fBCd7dc90bD6： 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps26.jpg) 

由于攻击者不会公开自己的源码，所以我们只能通过分析攻击交易来分析攻击者在两个合约中实现了什么样的功能。

通过MetaSleuth工具分析攻击。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps27.jpg) 

进一步通过Phalcon工具分析这个交易。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps28.jpg) 

所以我们可以得出在30攻击合约中存在的功能之一为：

1）有一个叫invest的函数，实现调用ETHPledge合约中的pledge质押函数。然后我们回到攻击交易分析。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps29.jpg) 

返现30合约在整个攻击中实现了将自己的Discover代币转发给79合约。

所以我们可以得出在30攻击合约中存在的功能为：

1）有一个叫invest的函数，实现调用ETHPledge合约中的pledge质押函数。

2）0x3e30e90f函数（我们定义为attack函数），实现将自己的discover代币转发给79合约。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps30.jpg) 

可以看到，整个攻击交易是由79合约中的0x77db1582函数（我们定义为attackBegin函数）发起的。attackBegin函数只调用了pancakeSwap中BUSD-BSC-USD交易池的swap函数，借出2100个BSC-USD。在pancakeSwap项目中进行闪电贷需要在自己发起闪电贷的合约中执行pancakecall函数，这是一个回调函数，用来在一笔交易中向借款的交易池还款。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps31.jpg) 

可以看到79合约在pancakecall这个回调函数中被调用2次，且2次函数执行的函数功能不同，所以我们需要在79合约中设计一个flag的被调用标识来分开执行2次pancakecall函数调用。

对于第一次执行pancakeCall函数调用进行分析：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps32.jpg) 

主要实现了再一次向PancakeSwap: Discover-BSC-USD交易池的swap函数再次借款，调用代币交换的函数，最后还款。

对于第二次执行pancakeCall函数调用进行分析：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps33.jpg) 

第二次函数调用主要是执行了再次兑ETHpeldge质押，调用30合约中的attack函数，然后再向PancakeSwap: Discover-BSC-USD交换池还款BSS-USD代币。

所以我们可以得出在30攻击合约中存在的功能为：

1）有一个叫attackBegin的函数，是整个攻击交易的入口，实现调用pancakeSwap的swap函数。

2）pancakecall函数，实现2次swap回调，执行不同的逻辑。

Hardhat.config.js配置文件进行配置修改：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps34.jpg) 

设置hardhat网络，进行配置hardhat币安主链URL配置，因为此闪电贷攻击发生在币安主链上区块号为18446846时间上，所以我们要fork到攻击还未发生的上一个区块中去做攻击复现。

首先现复现好攻击者的部署的两个攻击合约，这里成为30合约和79合约。

***\*30合约\****用主要用来实现攻击前的资金准备。使用30合约对受害者ETHplege合约进行存储。执行30合约的额plegein函数。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps35.jpg) 

Plegein函数的功能是质押，并且将质押人相关信息存储到ETHplege合约中。30合约还一个attack函数，用以整个攻击交易中的调用。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps36.jpg) 

***\*79合约\****。首先是79合约的构造函数。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps37.jpg) 

构造函数目的是拿到79合约需要交互的合约实例，方便79合约与其他合约进行调用，简化操作。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps38.jpg) 

AttackBegin是整个攻击交易发生的入口。该函数执行的是执行pancakeswap交易所的闪电贷功能。改swap函数需要执行调用者合约中的pancakecall的回调函数，如果没有回调函数改交易就会失败被revert。所以79合约要一个pancakecall回调函数。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps39.jpg) 

之前说到pancakeCall函数在2次调用中要实现不同的的函数逻辑，所以需要通过flag来标识第几次执行pancakeCall函数的内部逻辑。

第一次pancakeCall函数回调。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps40.jpg) 

第二次pancakeCall函数回调。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps41.jpg) 

至此，在智能合约上的准备和分析完成。

接下来我们需要在hardhat上去实现攻击复现。

***\*1.部署合约。\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps42.jpg) 

该函数是异步函数，传入的参数为合约名和合约构造函数需要的参数。

然后将该函数模组导出，在attack-reproduction脚本中引用。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps43.jpg) 

首先通过ethers拿到本地网络的用户数组，使用用户0作为攻击复现者。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps44.jpg) 

然后在beforeAttack_tranferToAttack函数中进行攻击前的资金准备。调用部署函数并传入attack30 字符串参数。这样我们就能够将30合约部署上链。然后获取到部署到的attack 30 合约的地址，作为部署attack 79 合约的第二个参数。此时我们将attack30合约和attack79合约都部署上链。

***\*2.调用\*******\*attack30.invest()\*******\*和\*******\*attack79.attackBegin()\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps45.jpg) 

目的是向ETHpeldge项目方以30合约的地址进行质押，留下30合约的信息。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps46.jpg) 

79合约的attackBegin执行借款。是整个攻击交易的开始。

***\*3.运行靶场与复现\****

首先需要执行 yarn hardhat node，该命令的功能是运行起hardhat本地私链。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps47.jpg) 

然后运行以下命令：

yarn hardhat run .\scripts\Discover-reproduction.js --network localhost

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps48.jpg) 

可以在控制台窗口看到打印出的信息。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps49.jpg) 

***\*时序图如下：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps50.jpg) 

***\*总结\****：黑客通过利用闪电贷和多个交易对，首先获取了一定数量的bsc_usd。然后，将部分资金转移到另一个账户，并执行多次交换操作，最终将discover转换为更多的bsc_usd。在修复闪电贷借款后，黑客最终获利，留下了可观的bsc_usd余额。

# 二、重入攻击

## 2.1 什么是重入攻击

智能合约在交易执行过程中难以保证运行环境的完全安全。当智能合约调用恶意的外部合约时，可能会出现重入攻击。重入攻击是指在一次调用中，合约中的函数通过递归方式多次执行，绕过检查从而重复获得如转账收益的行为。这种攻击方式是智能合约中最具破坏性的之一，曾在EOS平台和以太坊平台上多次发生。以太坊历史上造成最大损失的TheDAO攻击便是通过重入攻击实现的。攻击者通过在一次主动调用中递归地多次执行取款函数，不断从合约账户中分离资金，直至耗尽合约账户的资金，最终达成攻击目标。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps51.jpg) 

在以太坊中，智能合约可以通过call.value的方式发送以太币到外部合约。call.value可以指定两个参数：发送的以太币数量以及发送完毕后要执行的目标地址函数。如果目标函数不存在，则会默认执行目标地址中的fallback回调函数。此设计原本是为了实现转账后的通知机制，但恶意外部合约可以利用这一点，在回调函数中重新调用原合约的call.value函数继续提款。由于原合约的状态尚未更新完成，关键的余额检查被绕过，导致在一次调用中多次窃取资金。

重入攻击通过利用智能合约未完成的中间状态，多次递归调用提款函数，最终耗尽合约账户资金。这种攻击方式的破坏力极大，开发者必须在智能合约编写时采取防御措施，如使用重入锁或检查-效果-交互模式，以防范此类攻击。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps52.png)

在Hyperledger Fabric中，通过指定目标链码的名称，并使用 InvokeChaincode 函数可以实现链码之间的调用。然而，如果在目标链码的函数中也使用了相同的 InvokeChaincode 函数调用原链码中的函数，就可能为重入行为提供基础。虽然这种重入行为在 Fabric 中可能不会导致资金损失，但也可能为信息泄露带来风险。

2016 年 6 月 17 日，当时区块链领域最大的众筹项目 TheDAO 遭到攻击。攻击者利用 TheDAO 智能合约中的重入漏洞，不断从合约中分离 DAO 资产并转移到自己的账户中。通过 200 多次递归调用，攻击者将 300 多万以太币转移到自己的账户，这直接导致了以太坊分叉为 ETH 和 ETC。

2020 年 9 月 10 日，EOS 生态中的 DeFi 流动性挖矿项目合约 eoswramtoken 遭到重入攻击，损失超过 12 万 EOS。2020 年 4 月 19 日，攻击者对去中心化借贷项目 dForce 的 Lendf.Me 进行重入攻击，利用恶意代币合约盗走了价值约 2500 万美元的加密数字货币。与上述漏洞类似，OpenZeppelin 中的 ERC20 合约也存在类似问题。其根本原因在于，当受害者调用代币合约的转账函数时，如果该代币本身是恶意代币，其转账函数调用可能被引导到其他未知代码空间，从而存在重入问题。

2020 年 11 月 12 日，去中心化金融项目 Akropolis 遭受类似重入攻击，导致 203 万美元的损失。这些事件表明，重入攻击不仅能导致严重的经济损失，还会对整个区块链生态系统的安全性带来重大挑战。开发者需要采取严格的防御措施，如重入锁和检查-效果-交互模式，以防范此类攻击。

## 2.2重入攻击案例分析

***\*案例介绍：\****

2024年2月，Polygon上的项目Smoofs遭到攻击，项目被攻击的原因是项目设计中存在漏洞，导致被攻击者利用从而发生了重入漏洞，导致丢失4350 MOOVE，其价值目前不得而知。

Total lost: 4350 MOOVE

攻击者: 0x149b268b8b8101e2b5df84a601327484cb43221c

攻击合约:0x367120bf791cc03f040e2574aea0ca7790d3d2e5

被攻击合约: 0x9d6cb01fb91f8c6616e822cf90a4b3d8eb0569c6

攻击交易哈希:

0xde51af983193b1be3844934b2937a76c19610ddefcdd3ffcf127db3e68749a50

***\*攻击前的准备：\****

该项目的关键安全问题可以分为以下几点：

***\*NFT与ERC20代币交互\****：用户可以将自己的NFT (例如：Smoofs) 转移给项目方，以换取相应价值的ERC20代币 (MOOVE)。

***\*转账前未更新状态：\****关键的安全漏洞在于合约在更新内部状态（例如：用户的余额）之前先进行了转账操作。这种顺序错误留给了攻击者可乘之机。

***\*缺乏防重入保护：\****进行代币转账的函数没有使用防重入的修饰符，如 nonReentrant，这允许攻击者在合约的单个事务中多次调用此函数。

攻击者合约的重入调用：在执行代币转账时，合约调用了攻击者的合约。攻击者合约利用重入漏洞，在项目方合约完成状态更新之前，重新进入并触发额外的未授权转账。

***\*潜在的多次支付风险：\****由于合约逻辑的这种漏洞，攻击者可以多次从项目方合约中提取ERC20代币，导致项目方支付出超过原本预定额度的代币。

这些问题在下图中被详细概括，展示了漏洞存在的环节及其可能被利用的攻击路径。：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps53.jpg) 

***\*攻击流程：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps54.png) 

Step1.攻击者调用被攻击项目中的Stake函数，将自己的Smoofs质押给被攻击项目。

Step2.攻击者调用被攻击项目中的Withdraw函数，将自己质押的NFT对应的token取出。

Step3.在攻击者调用Withdraw函数之后，该函数会调用对应NFT项目中的safeTransferFrom函数，而该函数会回调攻击合约。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps55.jpg)![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps56.jpg)Step4.在被攻击项目回调攻击合约之后，攻击合约在函数中多次重入。

Step5.在所有的回调结束之后，被攻击项目调用removeStake函数进行状态变量改变。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps57.jpg) 

综上所述，本项目之所以会受到重入攻击是因为合约在转账之后才进行余额扣除(状态改变太晚)，并且还没有使用重入锁等防重入机制来防止重入的发生，这才导致漏洞被攻击者利用完成攻击。

## 2.3 重入攻击案例复现

***\*复现流程：\****

Step1.foundry环境准备：

Step2.代码复现：

我们在本地复现了攻击案例的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps58.jpg) 

(1)上图为配置实验环境，并且我们将本地的合约作为我们自己的攻击合约，用于复现整个攻击流程。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps59.jpg) 

(2)![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps60.jpg)我们将上述函数作为整个攻击交易的入口， 首先为了模拟整个攻击的流程，需要使用foundry内置的作弊码将一些资产转移到***\*本地攻击合约\****为攻击做准备，这些资产包括Smoofs NFT以及MOOVE代币，同时***\*本地攻击合约\****对***\*漏洞项目SMOOFSSTaking合约\****授权自己的NFT以及ERC20代币的使用权。

(3)之后在***\*攻击合约中\****调用漏洞项目***\*SMOOFSSTaking合约\****中的Stake函数，将自己的Smoofs NFT存入SMOOFSStaking合约，此时该合约拥有攻击者的NFT以及改NFT的使用权。

(4)攻击合约调用漏洞项目***\*SMOOFSSTaking合约\****中的Withdraw函数，想将上一步骤存入到***\*SMOOFSSTaking中\****的NFT转换成对应的MOOVE代币取出。

(5)之后，漏洞项目***\*SMOOFSStaking中的Withdraw函数会在改变状态变量之前\****会调用***\*被攻击项目Smoofs代币合约中的safeTransferFrom函数\****，而在这个函数中回调用攻击合约中的onERC721Received函数，最终造成了重入。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps61.jpg) 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps62.jpg) 

(6)我们只需要在本地onERC721Received函数中进行重入，不断地调用Smoofs合约中的safeTransferFrom函数，就可以让Smoofs合约不断地为我转账，并且还不减少我拥有的NFT余额：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps63.jpg) 

***\*攻击复现整体业务逻辑图为：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps64.jpg) 

# 三、操作预言机

## 3.1 什么是预言机

预言机(oracle )技术,用于解决在链上生成的不安全,经常被破解的随机数问题。0raclize提出了 oracle 架构[10](现名为 Provable)，用于支持以太坊、EOS、Fabric 的智能合约从链外获取数据，预言机的一般架构如下图所示:

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps65.jpg) 

在实际场景中，业务合约获取数据与链外程序投喂数据的过程是分开的，业务合约获取数据的流程如下:

(1)链外数据在链上会有一个用于注册服务请求的服务合约，服务合约用来连接链上与链外间的数据，当某个链上合约希望获取随机数时，可以向中间层服务合约的指定函数发起一个调用请求，并附带一些必要的参数，比如请求类型，返回格式或一些其他的条件。

(2)服务合约会将合约内保存的数据根据数据类型、请求参数进行处理，例如对于价格数据，预言机会根据预设好的基准价格指数再进行计算，保证价格数据不会因链外数据的波动而产生较大的异常值;而对于随机数请求，则会根据请求参数和已保存的链外随机数据再进行随机化处理，避免可能产生的随机数问题。

在这个过程中，如果请求的数据是诸如价格数据、随机数等已有的数据，服务合约不会主动发送事件向链外数据请求相应数据，而是由链外程序主动周期性地向服务合约通过交易调用向服务合约中投喂数据。只有当要请求的是服务合约中没有的数据，服务合约才会通过发送事件，并由链外程序投喂数据来进行数据的返回，流程如下:

(1)服务合约的接收到链外数据获取的请求后，合约内函数会产生一个特定的事件即 event并通过emit 发射到链外。

(2)链外的服务程序会通过接口(比如 web3j 包中的flowable 类)监控这个事件，从事件参数中获取到链上合约发送给链外服务程序的请求数据。

(3)链外服务程序会根据这些数据进行链外的请求，获取返回结果，然后将结果作为参数通过交易调用的方式交给服务合约中的结果处理函数，并保存在服务合约中。

这样架构的设计的优点是:

(1)周期性的投喂数据保证了一些常用数据可以即时获得保证了业务合约运行的连贯性。

(2)服务合约降低整个预言机系统中各层的合度，方便维护与升级，链上合约可以直接通过合约的标准规定进行请求。

(3)同一个服务合约也可以同时为多个不同的合约提供预言机来获取链外数据。

但是，在这个过程中也存在一些问题:

(1)新数据的获取需要经历链上到链下事件发射以及链下到链上的数据返回两轮共识，导致了较高的时间成本。

(2)链外数据源的安全与可信问题，也就是这样是否变为了以中心化的方式来获取数据从而违背了区块链去中心化的核心思想。为了解决单一数据源导致的预言机数据源中心化的问题，chainlink107在原有预言机的基础上进行了改进，其最大的变化在于其虚拟货币价格获取的过程中，使用了21家第三方机构的虚拟货币价格在链上整合计算后进行喂价，尽可能地避免因一家或两家的价格异常导致整体价格异常，一定程度上避免了数据源中心化的问题。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps66.jpg) 

## 3.2 什么是操作预言机

在智能合约安全领域，操作预言机的攻击是一种特别重要的安全威胁，通常出现在依赖外部数据源的区块链应用中。预言机（Oracle）是一种使智能合约能够访问链外（off-chain）数据的机制。因为智能合约运行在区块链上，本质上是封闭的，它们不能直接访问外部系统的数据，比如天气信息、股票价格、地理位置等。预言机桥接了这一差距，允许智能合约基于现实世界的数据做出决策。

***\*操作预言机的攻击简介\****

操作预言机的攻击是指攻击者操纵智能合约所依赖的外部数据源，以引发智能合约执行非预期的操作。这种攻击特别危险，因为它可以导致资金损失、不正确的执行逻辑等严重后果。

***\*如何进行操作预言机的攻击\****

数据源篡改：攻击者可以直接攻击数据源，改变供预言机使用的数据。例如，如果一个智能合约依赖某个API来获取股票市场价格，攻击者可能通过网络攻击该API，使其返回错误的价格信息。

中间人攻击：在数据从源头传输到预言机过程中，攻击者截取并修改数据。即使原始数据源是安全的，数据在传输过程中被篡改，也会导致智能合约基于错误的信息做出决策。

预言机自身的漏洞：如果预言机的实现本身存在安全漏洞，攻击者可以直接利用这些漏洞来操纵数据。这包括但不限于合约逻辑错误、权限过大等问题。

前馈攻击（Front-running）：攻击者通过监听即将到来的交易，然后在原交易之前快速发送另一个交易，以影响依赖于某些特定条件的合约执行结果。

## 3.3 操作预言机攻击案例分析

***\*案例介绍：\****

2023年1月，BEVO项目被攻击，造成144个BNB，约为45000美元的资产丢失，如果是按照今天的币价，这个数字还会更大，并且直接导致了BEVO代币的价格下跌了99%。项目被攻击的原因是由于该项目使用了价格预言机来作为当前代币价格，而价格预言机的模型在设计时却存在缺陷，导致该缺陷被攻击者利用，进行了价格操控。

Total lost: 144 BNB

抢跑者: 0xd3455773c44bf0809e2aeff140e029c632985c50

初始攻击者: 0x68fa774685154d3d22dec195bc77d53f0261f9fd

抢跑合约: 0xbec576e2e3552f9a1751db6a4f02e224ce216ac1

初始攻击合约:0xbf7fc9e12bcd08ec7ef48377f2d20939e3b4845d

被攻击合约: 0xc6cb12df4520b7bf83f64c79c585b8462e18b6aa

Attackhash:0xb97502d3976322714c828a890857e776f25c79f187a32e2d548dda1c315d2a7d

***\*攻击前的准备：\****

该项目是一个利用反射机理的通缩代币项目，一般来说在该种类型的项目中往往存在一个特性，即当某个通缩代币持有者销毁其通缩代币时，项目为了奖励该种类型代币的持有者，会自动的增加代币持有者的余额，但不会触发转账，只是修改一个系数。在这个机制中，用户持有的代币数量有两种，分别为tAmount和rAmount。tAmount为实际持有的代币数量，rAmount为体现的代币数量，比例为tTotal/rTotal。反射机制的token一般都有一个叫deliver的函数，这个函数会销毁调用者的token，降低rTotal的值，所以比例会增加，其他用户反射的token数量也会增加，攻击者注意到了该功能，并利用该功能对相应的Uniswap流动性池进行攻击，在Uniswap中，reserve就是储备资金，和token.balanceOf(address(this))有区别。攻击者首先调用 deliver 函数销毁自己的 token，导致 rTotal 的值减小，比例增大，因此反射出来的 token 的值也会增大，token.balanceOf(address(this)) 也会随之增大，导致和储备值出现差距。因此攻击者可以通过调用skim函数转移两个token之间的差额来获利。

值得一提是的本次攻击中，原始攻击者的攻击被链上抢跑机器人抢跑了，所以我们只分析抢跑的这笔交易，因为本质上抢跑交易使用的就是原始攻击交易的逻辑。首先，攻击者部署攻击合约：

0xbec576e2e3552f9a1751db6a4f02e224ce216ac1，该合约在浏览器上只能看到字节码，故对其进行反编译：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps67.jpg) 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps68.jpg) 

在反编译之后，我们仍无法直接通过分析伪代码去判断整个攻击的流程，唯一能发现的就是这个合约与很多攻击合约一样，有非常多的require判断条件，这些条件的设立目的，有两个，第一是确保只有自己能够成功调用该合约中的函数，成为攻击中的唯一受益方，第二确保其他人无法在短时间内分析出整个攻击的逻辑，从而仿照其攻击逻辑进行抢跑。所以如果这是一笔正在发生的攻击交易，我们承认我们确实无法分析出其攻击逻辑，但是我们可以肯定，目前绝大部分web3从业者肯定同样做到，所以我们只好将其作为一个笔已发生的交易，利用tracer通过该合约与其他合约已经发生了的关系，推断整个攻击逻辑，下面是tracer显示攻击的整个流程，并且我们使用红色方框圈出了整个攻击中最关机键的步骤：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps69.jpg) 

***\*攻击流程：\****

Step1.攻击者通过闪电贷从交易所中借出192.5 BNB，将这些BNB作为整个攻击的全部本金。

Step2.攻击者在交易所中将换取来的192.5BNB换成BEVO代币，该代币为通缩代币。

Step3.攻击者调用被攻击合约中的deliver函数，销毁自己BEVO代币，由于BEVO是通缩代币，除白名单之外的全部BEVO代币持有者的代币持有量都会增加。由于Pancake pair中同样持有BEVO代币，所以代币持有量也会增加。

Step4.攻击者调用pair中的skim函数，该函数会将pair中代币余额与代币储备量的差值转到任意地址，而由于攻击者上一步骤的deliver操作，导致pair中的余额大于存储量，所以该函数会将代币数量差值全部转移到攻击者设计的地址0xd3455773c44bf0809e2aeff140e029c632985c50上。

(***\*注意：这个过程中攻击者利用从pair中获取的代币数量与自己deliver销毁的代币数量的差值获利，其关键是保证这样一个不等式：y / rate  > x,其中y是pair中的bevo代币数量,rate是被攻击合约中的\*******\*r\*******\*Supply/\*******\*t\*******\*Supply,x是攻击者销毁的代币数量，\*******\*试\*******\*想y和rate都是公开的，所以攻击者只要使得x满足不等式，就能一直获利。\****)

Step5.攻击者再次调用被攻击合约中的deliver函数，故技重施，同样这次deliver的调用也导致了pair中的BEVO代币持有量增加。

Step6.攻击者调用swap函数，将pair中增加的全部BEVO全部换算成BNB，最终换取334BNB。

Step7.攻击者归还闪电贷借款。最终获利144BNB。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps70.jpg)以下是攻击的整个流程：

## 3.4 操作预言机攻击案例复现

***\*复现流程：\****

Step1.foundry环境准备：

Step2.代码复现：我们在本地复现了Discover攻击的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps71.jpg) 

(1)上图为配置实验环境，并且我们将本地的合约作为我们自己的***\*攻击合约\****，用于浮现整个攻击流程。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps72.jpg) 

(2)我们将上述函数作为整个攻击交易的入口， 首先***\*攻击合约\****授权***\*router合约\****，让其可以使用***\*攻击合约\****的wbnb代币并且***\*调用wbnb_usdc pair中的swap函数\****，从该pair对中借钱192.5 WBNB。

(3)在wbnb_usdc pair合约转钱给攻击合约之后，立刻会以闪电贷的方式回调攻击合约，在本地攻击合约收到回调之后迅速调用router合约中的函数将这些借来的WBNB换成BEVO代币,具体实现如下图所示：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps73.jpg) 

(4)紧接攻击合约调用漏洞项目BEVO代币合约中的deliver函数销毁从bevo_wbnb pair中换出来的bevo代币，由于BEVO代币是通缩代币，该操作会使得所有bevo代币的持有者中的代币数量增加，包括bevo_wbnb pair。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps74.jpg) 

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps75.jpg) 

(5)攻击合约迅速通过skim函数获取bevo_wbnb pair中增加的bevo代币数量，以此获利。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps76.jpg) 

(6)最后攻击合约重复上述过程，使得bevo_wbnb pair中代币数量增加，只不过最后并不是直接将bevo代币提取传来，而是换成了通过swap函数将pair增加的bevo代币换成wbnb，以WBNB的代币形式获利：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps77.jpg) 

(7)最后归还闪电贷欠款，实现获利：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps78.jpg) 

***\*攻击复现整体业务逻辑为：\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps79.jpg) 

## 4.1 整数溢出攻击

### ***\*4.1.1 攻击相关事件\****

整数溢出攻击案例介绍：

2024年2月8日，Ethereum主网上的ERC404项目Pandora遭到攻击，项目被攻击的原因是项目设计中存在漏洞，导致被攻击者利用从而发生了整数溢出漏洞，导致丢失约7.5 ETH，其价值约为350000$。

Total lost: 7.5 ETH

攻击者: 0x096f0f03E4BE68D7E6dD39B22a3846B8Ce9849a3

攻击合约: 0xCC5159B5538268f45AfdA7b5756FA8769CE3e21f

被攻击合约: 0xddaDF1bf44363D07E750C20219C2347Ed7D826b9

Attackhash:0x7c5a909b45014e35ddb89697f6be38d08eff30e7c3d3d553033a6efc3b444fdd

下图展示了该攻击的具体交易细节：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps80.jpg) 

图4-1 整数溢出攻击交易

### 4.1.2 攻击事件分析

#### ***\*4.1.2.1 攻击前的准备工作\****

该项目是一个ERC404项目，在该项目中，同时存在类似与ERC20的代币token以及与ERC721类似的NFT，且在该项目中一个完整的token(1e18)对应一个完整的NFT。所以在这个项目中同时存在转移ERC20代币与ERC721，也就是NTF的逻辑，但是项目本身在设计时，出现了整数溢出漏洞，导致攻击者可以利用该漏洞跳过转账中的身份检查以及逻辑验证等条件限制，不需要任何代价便可以操纵项目中的资金流动。分析得到的整个ERC404.sol的逻辑如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps81.jpg) 

图4-2 ERC404合约逻辑图



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps82.jpg) |

我们可以从下图中展示的合约部分截图的逻辑中看出，在该部分产生了整数下溢漏洞，从而导致攻击者可以借助这个漏洞，实现整数溢出攻击。



图4-3 整数溢出实现逻辑

#### ***\*4.1.2.2 攻击具体分析\****

通过对攻击交易的详尽分析，我们可以揭示出资金流向的具体情况，这通常通过可视化的方式在图表中展示，以便我们能够直观地看到资金是如何在攻击过程中从一个账户转移到另一个账户的。通过这种方式，我们可以追踪到攻击者的资金来源，识别出受影响的账户，以及资金最终的去向。这种详细的资金流向分析对于理解攻击的全貌、评估攻击的影响以及制定相应的防御措施至关重要。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps83.jpg) 

图4-4 整数溢出交易资金流向

此外，如下图所示，我们可以根据得到攻击交易具体的调用情况，用分析攻击具体的相关步骤。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps84.jpg)图4-5 整数溢出调用

***\*我们分析的流程如下：\****

***\*Step1.\****攻击者利用攻击合约调用被攻击合约中的tranferFrom()函数，将pandora_eth pair中的pandora代币几乎全都转移到pandora合约中。

***\*Step2.\****攻击者调用pandora_eth pair中的Sync()函数，强行是的pair中的balance和reserve一致，为接下来的攻击做准备。

***\*Step3.\****在攻击者再次调用tranferFrom()函数,再次利用溢出将pandora合约中的pandora全部转移到pair上，这时，pair中的pandora_balance会大于pandora_reverse，而这个差值会全部算到攻击者头上，攻击者得以获利。

***\*Step4.\****攻击者调用swap函数，将pandora迅速转移成ETH，攻击完成。

因此，可以画出具体的攻击事件分析的时序图如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps85.jpg) 

图4-6 攻击时序图

这里需要解释一下为什么会发生两次transferFrom的原因：

首先，在第一次调用transferFrom之前，在pair中pandora_balance和pandora_reserve的数量是一致的；

其次，在第一次发生transferFrom之后，pair中pandora_balance减少，但是pandora_reserve不变，所以调用了sync函数使得二者强行进行匹配；

最后，在第二次transferFrom发生之后，pair中pandora_balance增加，pandora_reserve不变，所以增加的这部分(pandora_balance - pandora_reserve)就算在了攻击者头上，从而使得攻击者可以获利，也反应出了攻击者可以利用整数溢出攻击的方式，达到攻击意图，实现攻击目的。

### ***\*4.1.3 攻击事件复现\****

#### ***\*4.1.3.1 复现具体流程\****

***\*Step1.\****攻击复现的foundry环境准备：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps86.jpg) 

图4-7 foundry环境准备

***\*Step2.\****代码复现：

我们在本地复现了攻击案例的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps87.jpg)首先，我们定义了一个ContractTest合约，继承自Test，并在其中引用了几个外部合约和库，包括WETH（一个IERC20接口实例），PANDORA（一个 PandorasNodes404合约实例），V2_PAIR（一个Uniswap V2流动性池合约实例），和cheats（一个CheatCodes实例，用于测试），定义后用于与这些外部合约进行交互，如下图所示。

图4-8 整数溢出实现逻辑1

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps88.jpg)其次，我们定义了testExploit函数，这个函数的主要目的是在进行攻击测试之前记录当前合约的状态。首先，它会打印当前合约的地址以供调试使用。然后，通过事件记录攻击者合约在攻击前的WETH和PANDORA代币余额，利用这些信息来监控攻击前的状态变化。接着，函数获取并存储了V2_PAIR合约中 PANDORA代币的余额，为后续的攻击操作和结果分析做准备，如下图所示，显示了具体的实验环境配置。

图4-9 整数溢出实现逻辑2

我们将上述函数作为整个攻击交易的入口，首先获取整数溢出的值。然后调用transferFrom()函数在testExploit函数中，代码首先通过PANDORA.transferFrom 函数从V2_PAIR合约转移一部分PANDORA代币到攻击者合约中，利用整数溢出的技巧绕过授权检查。接着，V2_PAIR.sync()用于同步余额的数据，获取了 V2_PAIR合约中的ETH余额和PANDORA代币的余额。随后，再次通过 PANDORA.transferFrom将一部分PANDORA代币从攻击者合约转移回V2_PAIR 合约中，利用相同的技巧绕过授权检查。接着，计算V2_PAIR合约中新的 PANDORA代币与旧代币之间的差额，并计算进行兑换所需的swapAmount。最后，通过调用V2_PAIR.swap函数将计算出的PANDORA代币数量兑换成WBNB代币。函数结束时，记录了攻击者合约中WETH和PANDORA代币的最终余额，以便分析攻击后的效果，如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps89.jpg)图4-10 整数溢出实现逻辑3

#### 4.1.3.2 复现最后效果

我们可以从下图看出，攻击后WETH和pandora的变化情况。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps90.jpg) 

图4-11 整数溢出实现1

此外，我们进一步提供了详尽的打印输出，这些信息不仅包括了基本的交易数据，还涵盖了交易的深度分析，如交易的执行路径、智能合约的交互细节、调用的函数及其参数、以及交易过程中可能发生的任何异常或错误。这种深入的信息展示，使得用户能够对交易的每一个环节都有一个清晰的认识，从而在进行安全审计或开发调试时，能够更加精确地定位问题所在，提高问题解决的效率。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps91.jpg) 

图4-12 整数溢出实现2



## 4.2 抢先交易攻击

### 4.2.1 攻击相关事件

2023年1月19日，Ethereum主网上的通缩代币项目SHOCO被攻击，并且由于初始的攻击者没有利用MEV和flashbots，而是将该攻击交易通过公用的交易池进行打包上链，但是在该交易被送进交易吃的瞬间，链上的MEV机器人就瞬间分析出该交易是一笔攻击交易，并且复制了该攻击交易的全部信息并将收益地址更改为抢跑者，最后通过MEV对初始的攻击交易进行抢跑，最后抢跑者获利约4.3 ETH($14000)。

Total lost: 4.3 ETH

初始攻击者: 0x14d8ada7a0ba91f59dc0cb97c8f44f1d177c2195

攻击合约: 0x15d684b4ecdc0ece8bc9aec6bce3398a9a4c7611

被攻击合约: 0x31A4F372AA891B46bA44dC64Be1d8947c889E9c6

抢跑者：0xe71aca93c0e0721f8250d2d0e4f883aa1c020361

抢跑机器人：0x000000000000660deF84E69995117c0176bA446E

抢跑攻击：0x2e832f044b4a0a0b8d38166fe4d781ab330b05b9efa9e72a7

a0895f1b984084b

下图中展示了抢跑交易攻击的具体交易细节：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps96.jpg) 

图4.16 抢跑交易攻击细节

### 4.2.2 攻击事件分析

#### 4.2.2.1 攻击前的准备工作

我们详细阅读了整个SHOCO_exp.sol文件。这个合约文件展示了一个针对SHOCO代币的攻击过程，攻击者通过调用deliver函数销毁自己的SHOCO代币，使得Uniswap交易对中的SHOCO代币数量增加，然后利用skim函数将这些增加的代币转移回自己的账户，重复上述过程直到满足一定条件，再调用swap函数将累积的SHOCO代币换成ETH，并通过抢跑机器人支付更高的交易费让矿工提前打包交易以完成攻击，最终记录攻击的利润或损失。

最后，我们对抢跑机器人进行反编译如下图所示：



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps97.jpg) |

图4.17 反编译代码



该项目是一个利用反射机理的通缩代币项目，一般来说在该种类型的项目中往往存在一个特性，即当某个通缩代币持有者销毁其通缩代币时，项目为了奖励该种类型代币的持有者，会自动的增加代币持有者的余额，但不会触发转账，只是修改一个系数。在这个机制中，用户持有的代币数量有两种，分别为tAmount和rAmount。tAmount为实际持有的代币数量，rAmount为体现的代币数量，比例为tTotal/rTotal。反射机制的token 一般都有一个叫deliver的函数，这个函数会销毁调用者的 token，降低 rTotal 的值，所以比例会增加，其他用户反射的token数量也会增加，攻击者注意到了该功能，并利用该功能对相应的 Uniswap 进行攻击，在Uniswap中，reserve就是储备资金，它和token.balanceOf(address(this))有区别。攻击者首先调用 deliver 函数销毁自己的 token，导致rTotal的值减小，比例增大，因此反射出来的token的值也会增大，token.balanceOf(address(this)) 也会随之增大，导致和储备值出现差距。因此攻击者可以通过调用skim函数转移两个token之间的差额来获利。

#### 4.2.2.2 攻击具体分析

首先，我们分析了造成此次攻击事件的攻击的资金具体流向，如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps98.jpg) 

图4.18 攻击资金流向

简单分析机器人的攻击交易以及原始的攻击合约，可以发现本次攻击与TINU类似，但攻击者使用了更为复杂的skim->deliver调用链。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps99.jpg) 

图4.12 攻击合约

值得一提的是，原始攻击者并没有使用Flashbots的隐私服务来发送攻击，代码只进行了验证msg.sender，这使得发起的交易容易受到抢先交易的攻击。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps100.jpg) 

图4.19 抢先交易攻击地址信息

然而，该机器人使用Flashbots发起交易，向Builder贿赂0.09以太币，最终获利约4.067以太币。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps101.jpg) 

图4.20 攻击获利情况

攻击结束后，rTotal下降，tFeeTotal上升，说明该漏洞应该与TINU一致。显然，实际获利4.3 Ether比最初攻击的约4.16 Ether略多。因此，在进一步检查SHOCO代币后发现，与Nomad Bridge攻击相关的人，在一个月后又对其发起了另一次攻击。另外可以观察到，所使用的攻击合约是由另一个地址0x961C44Acf3198Da23e289445D3dB6a7531890b50部署的，由于其合约没有任何保护措施，因此直接被0x1dbd使用来完成抢先交易。

其次，我们来具体分析整个攻击事件的调用过程，深入理解攻击的内核原因，如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps102.jpg) |

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps103.jpg)图4.21 攻击内核逻辑



***\*从具体调用我们可以了解到整个事件攻击的整体步骤如下：\****

***\*Step1.\****通过sentio对该攻击交易进行分析发现，攻击的流程，主要是通过不断地deliver销毁攻击者自己的shoco代币，使得pair中的shoco代币不断增加，并迅速地调用skim将pair中增加的shoco代币转移回来。这个过程，攻击者的shoco代币数量会一直增加。

***\*Step2.\****由于deliver函数获利的条件是需要满足不等式：y（1/rate - 1）> x,其中y是pair中的shoco代币数量,rate是被攻击合约中的tSupply/rSupply,x是攻击者销毁的代币数量，所以攻击者一直重复上述的过程直到不等式被打破。

***\*Step3.\****攻击者调用swap函数，将pair中不断累积的shoco代币全部置换为ETH，至此攻击完成。

***\*Step4\****.抢跑，相比于最初始的攻击交易的交易费0.005251913355283232ETH，该抢跑机器人给了矿工0.09ETH，让矿工提前打包自己的交易，完成攻击。

***\*根据分析，我们可以得到逻辑的时序图如下。\****

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps104.jpg) 

图4.22 抢先交易逻辑时序图



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps105.jpg) |

最后，我们展示了根据分析得到的交易信息，下图为它的详细信息：



![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps106.jpg)图4.23 初始交易与抢跑交易

### 4.2.3 攻击事件复现

#### 4.2.3.1 复现具体流程

***\*Step1.\****Foundry环境准备：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps107.jpg) 

图4.24 foundry环境初始化

***\*Step2.\****代码复现：

我们在本地复现了攻击案例的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程：

下图为配置的实验环境。我们设置了一个接口IReflection，继承自IERC20，并定义了两个函数：deliver用于销毁指定数量的代币，tokenFromReflection用于根据反射量计算代币数量；合约SHOCOAttacker继承自Test，并初始化了三个变量，分别表示Uniswap的SHOCO-WETH交易对（shoco_weth），SHOCO代币合约（shoco），以及WETH代币合约（weth），通过设置这些接口和变量，合约可以与SHOCO代币和Uniswap交易对进行交互。

我们定义了testExploit函数用于模拟和执行一次针对SHOCO代币的攻击。首先，函数将当前的区块高度设置为attackBlockNumber以模拟特定的区块链状态，然后使用vm.rollFork函数切换到该区块高度，并记录攻击前合约地址的WETH余额，通过console.log和emit log_named_decimal_uint函数输出WETH余额，如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps108.jpg) |

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps109.jpg)图4.25 攻击操作



我们将上述函数作为整个攻击交易的入口， 注意我们并没有像攻击交易一样做了那么多deliver与skim操作，我们是直接跳过了前面的金钱累计操作，直接进行了最后的deliver(因为在靶场上我们能够用作弊码让我们直接拥有足够的资金)，如下图所示。

在testExploit函数中，首先输出在shoco_weth交易对中SHOCO代币的初始余额，然后调用deliver函数销毁几乎所有的SHOCO代币，从而增加交易对中的SHOCO代币数量，并再次输出shoco_weth交易对中SHOCO代币的余额以查看变化。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps110.jpg) 

图4.26 攻击流程

#### 4.2.3.2 复现最后效果

运行我们设计的复现脚本，可以看到如下图所示的攻击结果，从图中可以看到，在进行攻击之前，账户的余额是没有WETH的，在进行攻击之后，可以发现账户的余额多出了WETH，也就说明获利了4.3WETH，从而证明实现了抢先交易攻击，如图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps111.jpg) |

4.27 抢先交易实现1



同时，在更加详细的打印的log信息中可以发现，代币之间具体的转换情况和变化。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps112.jpg) 

4.28 抢先交易实现2

## 4.3 操纵区块时间攻击

### 4.3.1 攻击相关事件

2024年4月25日，BSC主网上的代币项目FENGSHOU遭到攻击，该攻击是由于项目中存在错误的权限控制所导致任何人都可以对项目中的资金数量进行更改，本次攻击造成约 $90000的损失。

Total lost: $90000

攻击者: 0xd03d360dfc1dac7935e114d564a088077e6754a0

攻击合约: 0xc73781107d086754314f7720ca14ab8c5ad035e4

被攻击合约: 0xa608985f5b40cdf6862bec775207f84280a91e3a

攻击交易：0x8ff764dde572928c353716358e271638fa05af54be69f043df72ad9a

d054de25

下图展示了攻击交易的具体行为细节：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps113.jpg)图4.29 攻击交易细节

### 4.3.2 攻击事件分析

#### ***\*4.3.2.1 攻击前的准备工作\****

我们利用sentio explorer追踪交易中的资金流动：



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps114.jpg) |

图4.30 攻击资金流动





|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps115.jpg) |

并且我们在BSCScan浏览器上查找到被攻击合约，并获取其合约代码：



图4.31 被攻击合约代码

我们分析了NGFSToken.sol文件及其合约代码，大致的逻辑如下：这个合约是一个标准的BEP20协议，名为NGFSToken，符号为NGFS。它包括基本的ERC20功能，如代币转账、批准和代币铸造。此外，合约设置了买卖交易的基金费，并且可以对流动性提供和移除操作收取费用。合约还包含防止批量机器人攻击的机制，通过在交易开始区块的基础上设置杀区块和批量机器人杀区块号来限制恶意机器人交易。同时，合约提供了白名单功能，可以将特定地址排除在费用之外。合约还允许合约拥有者启动和关闭交易、管理流动性对的地址，并提取合约中的余额或其他代币。

同时，我们分析了NGFS_exp.sol文件及其合约。合约展示了一个针对 NGFS的攻击通过调用被攻击合约的delegateCallReserves()和 setProxySync(address)函数，攻击者绕过权限检查，将攻击合约设置为代理合约，然后调用 reserveMultiSync(address, uint256)函数将大量代币转移到攻击者账户，最后在PancakeSwap上将这些代币兑换成USDT，实现了非法获利。

#### ***\*4.3.2.2 攻击具体分析\****

首先，我们分析了造成此次攻击事件的攻击的资金具体流向，如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps116.jpg) 

图4.32 资金流向

其次，我们来具体分析整个攻击事件的调用过程，深入理解攻击的内核原因，如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps117.jpg) |

图4.33 攻击调用过程



***\*Step1.\****对攻击流程进行分析，攻击者首先部署了攻击合约，并利用攻击合约完成了以下内容：

***\*Step2.\****在攻击合约中，攻击者首先调用delegateCallReserves() 函数将被攻击合约中的_uniswapV2Proxy变量设置为当前的攻击合约，使得step3的条件检查得以通过。

***\*Step3.\****随后攻击者调用setProxySync()函数将被攻击合约中的变量_uniswapV2Library设置为攻击合约，使得step4中的条件检测得以通过。

***\*Step4\****.攻击者调用reserveMultiSync()函数，将攻击者输入的攻击者低地址上的金额增加。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps118.jpg)图4.34 攻击调用函数

***\*Step5\****.攻击者将获取到的multiSync代币通过Uniswap全部置换为usdt，即对应美元的稳定币。

综合分析该项目的智能合约代码，我们发现尽管开发者试图通过在关键函数前实施权限控制来限制对这些函数的调用，但这些控制措施的设计存在明显的缺陷。权限控制的不恰当设计导致它们很容易被规避，攻击者可以利用这些漏洞来绕过正常的权限验证机制。更具体地说，攻击者可以操纵合约的逻辑，为自己的账户任意设定代币数量，这不仅破坏了代币应有的稀缺性和价值，还可能引发代币经济系统的崩溃。这种设计上的漏洞严重威胁到了整个项目的安全性和信任度，需要立即进行修复和加固，以防止潜在的经济损失和声誉风险。

根据我们得到的分析，我们画出该攻击具体的时序图如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps119.jpg) 

图4.35 攻击时序图

### 4.3.3 攻击事件复现

#### ***\*4.3.3.1 复现具体流程\****

***\*Step1.\****Foundry环境准备：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps120.jpg) 

图4.36 foundry环境初始化

***\*Step2.\****代码复现：

我们在本地复现了攻击案例的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程。

下图展示了我们配置的实验环境。我们指定了用于分叉BSC链的区块号和重要合约地址，包括PancakeSwap的工厂和路由器地址、目标NGFS代币地址以及USDT代币地址。并在setUp函数中，利用vm.createSelectFork方法从指定区块号创建一个BSC链的分叉，为后续的攻击测试提供了基础环境。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps121.jpg) |

图4.37 攻击实验配置





|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps122.jpg) |

下图展示的这段代码的是测试对NGFS合约的攻击，我们通过获取攻击前的USDT余额来记录攻击前的状态，然后通过调用PancakeFactory合约的 getPair 函数获取NGFS代币和USDT代币的交易对地址，为后续的攻击步骤做准备。



图4.38 攻击实现1

我们将上述函数作为整个攻击交易的入口，我们接下来复现了整个攻击交易的流程：首先，攻击者调用delegateCallReserves()函数，将NGFS合约中的_uniswapV2Proxy变量设置为当前攻击合约的地址，绕过了正常的访问控制。随后，调用setProxySync(address(this)) 函数，将_uniswapV2Library变量也设置为攻击合约的地址，以满足后续函数的条件。接着，攻击者获取了交易对合约中NGFS代币的余额，并输出了攻击合约中NGFS代币的余额变化。最后，调用reserveMultiSync(address(this), balance) 函数，利用上述漏洞将交易对合约中的NGFS代币转移到攻击者的账户，从而非法获得代币。我们设置攻击前后的打印信息，来展示攻击对账户资金造成的变化，具体的代码如下图所示。![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps123.jpg)

图4.39 攻击实现2

最后，我们将攻击者从NGFS代币中获得的收益转换为USDT稳定币，具体的操作为：首先，攻击者获取了合约中NGFS代币的余额，并批准PancakeSwap路由合约可以花费这些代币。接着，设置了一个包含两个代币的路径数组，然后调用swapExactTokensForTokensSupportingFeeOnTransferTokens函数，将所有的NGFS代币交换为USDT稳定币，完成代币兑换操作。最后，计算并记录了攻击前后USDT代币余额的变化，显示攻击者从此次攻击中获得的USDT利润。我们通过模拟攻击者如何将非法获得的代币转换为价值更高的稳定币，从而     实现最终的利益最大化，实现攻击者对资金的利用，实现攻击复现。![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps124.jpg)

图4.40 攻击实现3

#### ***\*4.3.3.2 复现最后效果\****

我们打印了攻击前后有关的log信息，可以发现：在调用非法转移代币函数之前，NFGS代币合约的资金为0，但是在调用了非法转移代币的合约之后，可以从下图中发现，该合约的资金产生了很大的变化。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps125.jpg) 

图4.41 攻击复现效果1

从复现打印的log中可以看到具体的攻击结果，在攻击之前，攻击者账户的余额只有大约26，然后，经过抢先交易攻击之后，攻击者的余额达到了大约95902，总共活力大约95000USDT，这样证明了我们成功对攻击进行复现，实现了攻击,如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps126.jpg) |

图4.42 攻击复现效果2



下图展示了更加详细的打印信息，可以看到，我们调用了合约的 delegateCallReserves 函数并设置了代理合约为攻击合约，表示成功执行。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps127.jpg) 

图4.43 攻击复现效果3

## 4.4 闪电贷攻击

### 4.4.1 攻击相关事件

2024年5月22日，Burner项目遭到闪电贷攻击，此次攻击中攻击者结合了闪电贷与抢跑攻击操纵，利用闪电贷借出的大量资金在去中心化交易池中进行交易，从而提高一种代币的价格，属于基于询价机制的闪电贷攻击。

攻击者：0xe6DCF87256866e293B825708bF1F5DF8f07519B3

攻击合约：0x1BCC8378943aAeE2d99A4e73ddf6C01F62825844

被攻击项目：0x4d4d05e1205e3A412ae1469C99e0d954113aa76F

Attachhash:0x3bba4fb6de00dd38df3ad68e51c19fe575a95a296e0632028f101c5199b6f714

获利：1.7ETH(约$6400)

下图展示了闪电贷攻击的具体交易细节：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps128.jpg)图4.44 闪电贷攻击交易细节

### 4.4.2 攻击事件分析

#### ***\*4.4.2.1 攻击前的准备工作\****

该项目是一个类似于加密货币交易所的平台，它提供了与UniswapV2这样的去中心化交易所进行代币交易的功能。在这个平台上，用户可以执行交易操作，直接影响到交易所中特定流动性池（如weth_pnt pair）中两种代币的余额。这种设计允许用户在平台上进行代币的买卖，同时也为攻击者提供了可利用的漏洞。攻击者通过精心设计的交易策略，利用这些业务逻辑中的缺陷，对该项目发起攻击，目的是为了在代币交易中实现非法套利。下图展示了该项目中被攻击者利用的核心函数，这个函数是攻击发生的关键点，揭示了攻击者如何通过操纵交易逻辑来实现其套利目的。

在该项目中，流动性池的pair，即两种代币的组合，是交易的核心组成部分，它们共同维护着交易对的流动性和价格平衡。下图展示了该项目中被攻击者利用的核心函数，这个函数是攻击发生的关键环节，它揭示了攻击者如何通过操纵pair中的代币余额来实现其套利目的。

 



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps129.jpg) |

图4.45 攻击核心函数



在攻击者的Burner_exp.sol攻击脚本中，ContractTest智能合约演示了一个基于闪电贷的套利攻击策略。合约在 setUp() 函数中设置测试环境，模拟了主网的区块链状态，并将70 ETH分配给合约地址以进行攻击。在 testExploit() 函数中，合约首先模拟了从交易所借入70 ETH的闪电贷操作，并将这些ETH转换为WETH代币。接着，合约授权 Uniswap路由器对WETH和PNT代币进行操作，利用Uniswap将持有的WETH代币转换为PNT代币。随后，合约调用Burner合约的 convertAndBurn() 函数，通过传递三个代币地址（0x0、WBTC 和 USDT）来操控市场上的代币价格，达到提高WETH相对于PNT的市场价格的目的。市场操控完成后，合约再次使用Uniswap将手中的PNT代币兑换为WETH代币，并最终将70 ETH还给闪电贷方以模拟偿还闪电贷的操作。攻击结束后，合约记录并输出了攻击者获得的WETH利润，展示了通过这一系列操作实现套利的结果。合约通过模拟闪电贷借入70 ETH，转换为WETH，随后使用Uniswap将WETH兑换为PNT代币，接着利用Burner合约的 convertAndBurn() 函数操控市场价格，最后将PNT代币兑换回WETH，并偿还闪电贷，最终展示了攻击者从中获得的利润。

#### ***\*4.4.2.2 攻击具体分析\****

首先，我们分析了造成此次攻击事件的攻击的资金具体流向，如下图所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps130.jpg) 

图4.46 资金流向

其次，我们来具体分析整个攻击事件的调用过程，深入理解攻击的内核原因，如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps131.jpg) |

图4.47 攻击调用过程



***\*Step1.\****攻击者通过闪电贷从交易所中借来大量资金，总共70ETH。

***\*Step2.\****攻击者在收到交易所的swap回调之后，在回调中进行接下来的操作，包括如下：

***\*Step3.\****攻击者授权交易所能够动用自己的ETH资产，并将自己闪电贷来的ETH全部置换为PNT。

***\*Step4.\****攻击者利用置换来的PNT在被攻击项目中进行操作，由于被攻击项目使用的是以交易所为中介的模式，所以在Burner项目中的操作会直接影响到交易所中的代币数量，因此攻击者便进行一些交易(这些交易并不关键)。

***\*Step5.\****上述操作使得交易所中的pnt代币较少，weth代币增之后，意味着weth相对于pnt的价格更低了，此时，攻击者在使用自己闪电贷贷来的pnt全部置换为weth，此时换取的weth便达到了71.7weth，攻击者净获利1.7weth。

根据上述的步骤，我们画出整个攻击步骤的时序图如下所示。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps132.jpg) 

图4.48 闪电贷攻击时序图

### 4.4.3 攻击事件复现

#### ***\*4.4.3.1 复现具体流程\****

***\*Step1.\****Foundry环境准备：

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps133.jpg) 

图4.49 foundry初始化

***\*Step2.\****代码复现：

我们在本地复现了攻击案例的整个流程，在攻击过程中我们模拟攻击者原地址为整个交易的发起者，这样可以使得攻击合约中某些条件检测得以通过，我们编写了自己的攻击合约来复现整个交易流程：

如下图所示配置我们的实验环境，我们在 ContractTest 合约中定义了与不同智能合约和代币的接口，用于执行一系列的攻击操作。首先，IBurner burner_ 变量实例化了 Burner 合约，允许调用其 convertAndBurn() 函数来执行代币的转换和销毁，从而操控市场上的代币价格。接着，定义了 IERC20 usdt_、IERC20 wbtc_ 和 IERC20 pnt_ 分别对应USDT、WBTC和PNT代币的合约接口，这些代币在攻击过程中用于资金转移和市场操作。同时，IWETH weth_ 变量实例化了WETH代币的合约，支持WETH的存款和取款操作。最后，IUniswapV2Router router_ 实例化了Uniswap V2 路由器合约的接口，用于执行不同代币之间的兑换操作。通过这些接口，合约能够进行闪电贷、代币交换、市场操控等操作，从而完成攻击策略中的套利目标。![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps134.jpg)

图4.50 攻击实现1

在 testExploit 函数的这一部分，首先使用 console.log 打印了合约当前WETH代币余额，以便在攻击前观察状态。随后，我们使用合约模拟了一个闪电贷操作，向合约地址转账了70 ETH。这笔资金被存入WETH合约中，转换为等值的70 WETH代币，为接下来的攻击步骤准备了必要的资金。通过这种方式，我们就可以模拟攻击者获取用于攻击过程的资金，这些资金随后会用于在Uniswap上进行代币交易操作。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps135.jpg) |

图4.51 攻击实现2



我们将上述函数作为整个攻击交易的入口， 首先进行闪电贷，贷出70ETH并将这些ETH放入pair中用来置换pnt代币——我们模仿攻击者首先将70 ETH转换成WETH，然后授权Uniswap路由器能够使用合约中的WETH代币，并授权合约中的PNT代币。接下来，攻击者设置一个从WETH到PNT的交易路径，并调用swapExactTokensForTokensSupportingFeeOnTransferTokens函数，将合约中所有的WETH代币交换成PNT代币。这一步骤的目的是通过大量购买PNT来推高PNT的价格，为后续利用价格变化进行套利攻击做好准备，攻击者可以在价格被推高后，以更高的价格卖出PNT代币，实现利润的套取。整个攻击过程的详细步骤和逻辑在下图中得到了清晰的展示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps136.jpg) |

图4.52 攻击实现3





|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps137.jpg) |

接着，在被攻击者项目中进行代币置换操作，目的是为了减少交易池pnt，增加交易池weth，使得pnt价格上涨。我们调用了一些日志函数来标记攻击的开始和结束，并准备了一个包含三个代币地址（其中两个为WBTC和USDT）的数组。随后，调用了Burner合约的convertAndBurn函数来处理这些代币，紧接着，攻击者重新设置交易路径，将PNT转换回WETH，为最终套利交易做好准备，如下图所示。



图4.53 攻击实现4

最后将闪电贷来的pnt全部置换为weth。我们通过Uniswap V2路由器将所有的PNT换回WETH，从而实现获利；在完成套利交易后，攻击者将70 ETH还给了模拟的闪电贷提供者，并记录了最终利润，最终获利1.7weth，如下图所示。



|      |                                                              |
| ---- | ------------------------------------------------------------ |
|      | ![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps138.jpg) |

图4.54 攻击实现5



#### ***\*4.4.3.2 复现最后效果\****

通过下图可以看到进行闪电贷攻击的具体效果。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps139.jpg) 

图4.55 攻击复现效果1

此外，我们打印了更加详细的攻击信息作为参考，如下图所示。首先，我们打印了攻击前合约中的WETH余额，然后我们使用闪电贷进行借贷。这个时候我们可以看到，用WETH交换PNT之前和之后的余额情况。接着，我们调用合约中的函数进行攻击，可以看到在攻击结束后，我们又重新将PNT转换为WETH，最后，我们归还刚才借出的闪电贷，发现我们获取了1.7ETH的利润。

![img](file:///C:\Users\KEN\AppData\Local\Temp\ksohtml30776\wps140.jpg) 

图4.56 攻击复现效果2