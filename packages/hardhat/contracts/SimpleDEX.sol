// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleDEX is Ownable {
    // Instancias de los contratos ERC-20 TokenA y TokenB que se utilizarán para realizar los intercambios
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Variables para llevar el control de las reservas de liquidez para TokenA y TokenB
    uint256 public reserveA;
    uint256 public reserveB;

    // Declaración de eventos para notificar acciones clave en el contrato.
    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, uint256 amountIn, uint256 amountOut, bool isAtoB);

    // Constructor: Pasa msg.sender al constructor de Ownable
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // Función para añadir liquidez al pool
    function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA > 0 && amountB > 0, "Amount must be greater than zero");

        // Transferir tokens al contrato
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Actualizar las reservas
        reserveA += amountA;
        reserveB += amountB;

        // Emisión del evento de adición de liquidez.
        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    // Función para retirar liquidez del pool
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA <= reserveA && amountB <= reserveB, "Not enough liquidity");

        // Transferir tokens al owner
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        // Actualizar las reservas
        reserveA -= amountA;
        reserveB -= amountB;

        // Emisión del evento de retiro de liquidez.
        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // Función para intercambiar TokenA por TokenB
    function swapAforB(uint256 amountAIn) external {
        require(amountAIn > 0, "Amount must be greater than zero");
        
        // Verificar que el usuario tiene suficientes TokenA
        require(tokenA.balanceOf(msg.sender) >= amountAIn, "Insufficient TokenA balance");

        // Calcular la cantidad de TokenB que recibirá el usuario.
        uint256 amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut > 0, "Insufficient liquidity");

        // Transferir TokenA al contrato
        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        // Transferir TokenB al usuario
        tokenB.transfer(msg.sender, amountBOut);

        // Actualizar las reservas
        reserveA += amountAIn;
        reserveB -= amountBOut;

        // Emisión del evento de intercambio.
        emit TokenSwapped(msg.sender, amountAIn, amountBOut, true);
    }


    // Función para intercambiar TokenB por TokenA
    function swapBforA(uint256 amountBIn) external {
        require(amountBIn > 0, "Amount must be greater than zero");
        
        // Verificar que el usuario tiene suficientes TokenB
        require(tokenB.balanceOf(msg.sender) >= amountBIn, "Insufficient TokenB balance");

        // Calcula la cantidad de TokenA que recibirá el usuario basándose en las reservas actuales
        uint256 amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut > 0, "Insufficient liquidity");

        // Transferir TokenB al contrato
        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        // Transferir TokenA al usuario
        tokenA.transfer(msg.sender, amountAOut);

        // Actualizar las reservas
        reserveB += amountBIn;
        reserveA -= amountAOut;

        // Emitir un evento que notifica que el intercambio se realizó
        emit TokenSwapped(msg.sender, amountBIn, amountAOut, false);   
    }


    // Función para calcular el precio de intercambio basado en las reservas
    function getPrice(address _token) public view returns (uint256) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token address");

        uint256 price; // Variable para almacenar el precio calculado

        if (_token == address(tokenA)) {
            // Si el token es TokenA, calculo el precio de TokenA en términos de TokenB
            price = reserveB * 10 ** 18 / reserveA;
        } else {
            // Si el token es TokenB, calculo el precio de TokenB en términos de TokenA
            price = reserveA * 10 ** 18 / reserveB;
        }

        return price; // Devuelve el precio calculado
    }


    // Función para calcular la cantidad de tokens que se recibirán en un intercambio
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Amount must be greater than zero");
        
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}