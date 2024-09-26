import { useState } from 'react';
import reactLogo from './assets/react.svg';
import viteLogo from '/vite.svg';
import './App.css';
import { ButtonHard, ButtonSoft } from './buttons';

function App() {
  const handleClick = () => {
    alert('Botão clicado!');
  };

  return (
    <>
      <div className="Header">

        <ButtonSoft onClick={handleClick} text={'Explorar Rifas'}></ButtonSoft>
        <ButtonSoft onClick={handleClick} text={'Criar Rifas'}></ButtonSoft>
        <ButtonSoft onClick={handleClick} text={'Minhas Rifas'}></ButtonSoft>
        <ButtonHard onClick={handleClick} text={'Conectar Carteira'}></ButtonHard>

      </div>
      <div className="container">

        <div className="main-content">
          <h1>Conteúdo Principal</h1>
          <p>Este é o conteúdo principal da aplicação.</p>
        </div>

        <div className="right-column">
          <h2>Coluna da Direita</h2>
          <p>Este é o conteúdo da coluna da direita.</p>
        </div>

      </div>
    </>
  );
}

export default App;
