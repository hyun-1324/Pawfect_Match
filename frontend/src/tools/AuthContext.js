import React, { createContext, useContext, useState, useEffect } from 'react';
import useWebSocket from 'react-use-websocket';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {

  const [loggedIn, setLoggedIn] = useState(false);
  const [friendRequests, setFriendRequests] = useState([]);
  const [unreadMessages, setUnreadMessages] = useState(false);
 
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

  useEffect(() => {
    if (lastJsonMessage) {
      console.log(lastJsonMessage);
      // Save fried requests to state
      if (lastJsonMessage.event === "friendRequests") {
        if (lastJsonMessage && lastJsonMessage.data.ids !== null) {
          setFriendRequests(lastJsonMessage.data.ids);
        } else {
          setFriendRequests([]);
        }
      // Save unread messages to state
      } else if (lastJsonMessage.event === "unreadMessages") {
        if (lastJsonMessage.data === true) {
          setUnreadMessages(true);
        } else {
          setUnreadMessages(false);
        }
      } else if (lastJsonMessage.event === "error") {
        console.log("WS ERROR!" + lastJsonMessage.data);
      }
    }
  }, [lastJsonMessage]);

  const login = () => {
    setLoggedIn(true);
  };
  const logout = () => {
    setLoggedIn(false);
  }
  const clearFriendNotification = () => {
    setFriendRequests([]);
  }

  return (
    <AuthContext.Provider value={{ 
      loggedIn, 
      login, 
      logout, 
      sendJsonMessage, 
      friendRequests,
      unreadMessages,
      clearFriendNotification, 
  }}>
      {children}
    </AuthContext.Provider>
  );
};