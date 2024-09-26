import React from 'react';
import './buttons.css';

export const ButtonHard = ({onClick, text}) => {
    return (
        <button onClick={onClick} className='button-hard'>
            {text}
        </button >
    );
};

export const ButtonSoft = ({onClick, text}) => {
    return (
        <button onClick={onClick} className='button-soft'>
            {text}
        </button >
    );
};


