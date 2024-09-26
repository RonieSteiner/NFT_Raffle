// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftRaffle is ReentrancyGuard, Ownable {
    uint256 private _ticketCounter; // Contador para os bilhetes
    uint256 private _raffleCounter; // Contador para as rifas

    constructor() Ownable(msg.sender) {}
    // Estrutura para armazenar informações sobre a rifa
    struct Raffle {
        address nftOwner; // Endereço do dono da NFT
        address nftContract; // Endereço do contrato da NFT
        uint256 nftId; // ID da NFT
        uint256 ticketPrice; // Preço de cada bilhete
        uint256 totalTickets; // Número total de bilhetes
        uint256 endTime; // Tempo de término da rifa
        bool isActive; // Status da rifa (ativa ou não)
        mapping(uint256 => address) ticketOwners; // Mapeamento dos donos dos bilhetes
        mapping(address => uint256) refunds; // Mapeamento para armazenar o total a ser reembolsado para cada comprador
    }

    mapping(uint256 => Raffle) public raffles; // Mapeamento das rifas
    mapping(address => uint256) public pendingWithdrawals; // Mapeamento para armazenar os valores a serem retirados

    // Eventos para registrar ações importantes
    event RaffleCreated(uint256 raffleId, address nftOwner, uint256 nftId, uint256 totalTickets, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 raffleId, address buyer, uint256 ticketNumber);
    event RaffleEnded(uint256 raffleId, address winner);
    event RaffleRefunded(uint256 raffleId);
    event RaffleCancelled(uint256 raffleId, address nftOwner);
    

    // Função para criar uma nova rifa, precisa ser enviado o valor de 1% do valor total da rifa como taxa.
    function createRaffle(address nftContract, uint256 nftId, uint256 ticketPrice, uint256 totalTickets, uint256 duration) external payable nonReentrant {
        require(IERC721(nftContract).ownerOf(nftId) == msg.sender, "You must own the NFT to create a raffle");
        require(totalTickets > 0, "Total tickets must be greater than zero");
        require(ticketPrice > 0, "Ticket price must be greater than zero");

        // Calcula a taxa de 1%
        uint256 totalValue = ticketPrice * totalTickets;
        uint256 fee = totalValue / 100;
        require(msg.value == fee, "Incorrect fee amount");
        pendingWithdrawals[owner()] += fee;

        // Transferência da NFT para o contrato
        IERC721(nftContract).transferFrom(msg.sender, address(this), nftId);

        uint256 raffleId = _raffleCounter; // Obtém o ID da rifa atual
        _raffleCounter++; // Incrementa o contador de rifas

        // Criação da nova rifa
        Raffle storage raffle = raffles[raffleId];
        raffle.nftOwner = msg.sender;
        raffle.nftContract = nftContract;
        raffle.nftId = nftId;
        raffle.ticketPrice = ticketPrice;
        raffle.totalTickets = totalTickets;
        raffle.endTime = block.timestamp + duration;
        raffle.isActive = true;

        // Emissão do evento de criação da rifa
        emit RaffleCreated(raffleId, msg.sender, nftId, totalTickets, ticketPrice, raffle.endTime);
    }

    // Função para comprar um bilhete
    function buyTickets(uint256 raffleId, uint256 quantity) external payable nonReentrant {
        Raffle storage raffle = raffles[raffleId];
        require(raffle.isActive, "Raffle is not active");
        require(block.timestamp < raffle.endTime, "Raffle has ended");
        require(quantity > 0, "Quantity must be greater than zero");
        require(msg.value == raffle.ticketPrice * quantity, "Incorrect ticket price");
        require(_ticketCounter + quantity <= raffle.totalTickets, "Not enough tickets available");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 ticketNumber = _ticketCounter; // Obtém o número do bilhete atual
            _ticketCounter++; // Incrementa o contador de bilhetes
            raffle.ticketOwners[ticketNumber] = msg.sender; // Registra o dono do bilhete
            raffle.refunds[msg.sender] += raffle.ticketPrice; // Acumula o valor pago pelo comprador

            // Emissão do evento de compra de bilhete
            emit TicketPurchased(raffleId, msg.sender, ticketNumber);
        }

        // Se todos os bilhetes forem vendidos, encerra a rifa
        if (_ticketCounter == raffle.totalTickets) {
            endRaffle(raffleId);
        }
    }

    // Função interna para encerrar a rifa
    function endRaffle(uint256 raffleId) internal {
        Raffle storage raffle = raffles[raffleId];
        require(raffle.isActive, "Raffle is not active");

        raffle.isActive = false;

        // Se todos os bilhetes foram vendidos, sorteia um vencedor
        if (_ticketCounter == raffle.totalTickets) {
            uint256 winningTicket = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % raffle.totalTickets;
            address winner = raffle.ticketOwners[winningTicket];
            IERC721(raffle.nftContract).transferFrom(address(this), winner, raffle.nftId);
            emit RaffleEnded(raffleId, winner);

            // Calcula o valor total arrecadado
            uint256 totalCollected = raffle.ticketPrice * raffle.totalTickets;

            // Calcula a comissão de 5%
            uint256 commission = totalCollected / 20; // 5% é 1/20 do total

            // Calcula o valor a ser transferido para o dono da NFT
            uint256 ownerAmount = totalCollected - commission;

            // Disponibiliza 95% para o dono da NFT
            pendingWithdrawals[raffle.nftOwner] += ownerAmount;

            // Disponibiliza 5% para o dono do contrato
            pendingWithdrawals[owner()] += commission;
        } else {
            // Caso contrário, permite que os participantes solicitem o reembolso
            emit RaffleRefunded(raffleId);
        }
    }

    // Função para o comprador de rifa solicitar a devolução do valor dos tickets caso a rifa expire
    function claimRefund(uint256 raffleId) external nonReentrant {
        Raffle storage raffle = raffles[raffleId];
        require(!raffle.isActive, "Raffle is still active"); // Verifica se a rifa está encerrada
        uint256 refundAmount = raffle.refunds[msg.sender];
        require(refundAmount > 0, "No refund available");
        raffle.refunds[msg.sender] = 0; // Marca como reembolsado
        payable(msg.sender).transfer(refundAmount);
    }

    // Função para o dono da NFT ou dono do contrato sacar os fundos
    function claimFunds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available");

        pendingWithdrawals[msg.sender] = 0; // Marca como sacado
        payable(msg.sender).transfer(amount);
    }

    // Função para verificar o status da rifa e encerrá-la se necessário
    function checkRaffleStatus(uint256 raffleId) external {
        Raffle storage raffle = raffles[raffleId];
        if (block.timestamp >= raffle.endTime && raffle.isActive) {
            endRaffle(raffleId);
        }
    }

    // Função de leitura que só o dono do contrato pode chamar para verificar o saldo de pendingWithdrawals[owner()]
    function getOwnerPendingWithdrawals() external view onlyOwner returns (uint256) {
        return pendingWithdrawals[owner()];
    }

    // Função de leitura para checar se a rifa está ativa gásfree
    function isRaffleActive(uint256 raffleId) external view returns (bool) {
        Raffle storage raffle = raffles[raffleId];
        return raffle.isActive;
    }

    // Função para o dono da Rifa cancelar uma rifa em andamento
    function cancelRaffle(uint256 raffleId) external nonReentrant {
        Raffle storage raffle = raffles[raffleId];
        require(msg.sender == raffle.nftOwner, "Only the NFT owner can cancel the raffle");
        require(raffle.isActive, "Raffle is not active");

        raffle.isActive = false;

        // Calcula a taxa de 2%
        uint256 totalValue = raffle.ticketPrice * raffle.totalTickets;
        uint256 fee = totalValue / 50;
        pendingWithdrawals[owner()] += fee;

        // Devolve a NFT ao dono original
        IERC721(raffle.nftContract).transferFrom(address(this), raffle.nftOwner, raffle.nftId);

        // Libera os valores para reembolso dos compradores de tickets
        for (uint256 i = 0; i < _ticketCounter; i++) {
            address buyer = raffle.ticketOwners[i];
            raffle.refunds[buyer] += raffle.ticketPrice;
        }

        // Emite o evento de cancelamento da rifa
        emit RaffleCancelled(raffleId, raffle.nftOwner);
    }

}
