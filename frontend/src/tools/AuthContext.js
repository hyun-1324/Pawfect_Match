import React, { createContext, useContext, useState } from 'react';
import useWebSocket from 'react-use-websocket';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {

  const [loggedIn, setLoggedIn] = useState(false);
 
  const { 
    sendJsonMessage,
    lastJsonMessage, 
   } = useWebSocket("ws://localhost:8080/ws", {
    share: true,
    onOpen: () => console.log("WebSocket Connected"),
    onClose: () => console.log("WebSocket Disconnected"),
    // Will attempt to reconnect on all close events, such as server shutting down
    shouldReconnect: (closeEvent) => true,
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
    <AuthContext.Provider value={{ loggedIn, login, logout, sendJsonMessage, lastJsonMessage }}>
      {children}
    </AuthContext.Provider>
  );
};