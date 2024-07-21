import React, { createContext, useContext, useEffect, useState } from 'react';
import useWebSocket, { ReadyState } from 'react-use-websocket';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {

  const [loggedIn, setLoggedIn] = useState(false);
 
  const { 
    sendJsonMessage,
    lastJsonMessage, 
    readyState, 
    getWebSocket,
   } = useWebSocket("ws://localhost:8080/ws", {
    share: true,
    onOpen: () => console.log("WebSocket Connected"),
    onClose: () => console.log("WebSocket Disconnected"),
    // Add other event handlers as needed
  }, 
    loggedIn
  );

  const login = () => {
    setLoggedIn(true);
  };
  const logout = () => {
    setLoggedIn(false);
  }

  return (
    <AuthContext.Provider value={{ login, logout, sendJsonMessage, lastJsonMessage }}>
      {children}
    </AuthContext.Provider>
  );
};