import React, { createContext, useContext, useState, useEffect } from 'react';
import useWebSocket from 'react-use-websocket';
import AlertModal from '../components/navigation/Modal';
import fetchUserData from './fetchUserInfo';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {

  const [loggedIn, setLoggedIn] = useState(false);
  const [friendRequests, setFriendRequests] = useState([]);
  const [unreadMessages, setUnreadMessages] = useState(false);
  const [newConnections, setNewConnections] = useState([]);
  const [chatList, setChatList] = useState([]);
  const [statuses, setStatuses] = useState([]);

  const [showModal, setShowModal] = useState(false);
  const [userDataForModal, setUserDataForModal] = useState({});
 
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

  // Save incoming websocket messages to state
  useEffect(() => {
    if (lastJsonMessage) {
      console.log("Coming from server: ", lastJsonMessage);
      // Save fried requests to state
      if (lastJsonMessage.event === "friend_requests") {
        if (lastJsonMessage && lastJsonMessage.data.ids !== null) {
          setFriendRequests(lastJsonMessage.data.ids);
        } else {
          setFriendRequests([]);
        }
      // Add new value to friendRequests state
      } else if (lastJsonMessage.event === "friend_request") {
        // Make sure the id is a number type
        const id = parseInt(lastJsonMessage.data);
        setFriendRequests((prev) => [...prev, id]);
      // Save unread messages to state
      } else if (lastJsonMessage.event === "unread_messages") {
        if (lastJsonMessage.data === true) {
          setUnreadMessages(true);
        } else {
          setUnreadMessages(false);
        }
      // Save new connections to state
      } else if (lastJsonMessage.event === "new_connections") {
        if (lastJsonMessage.data.ids !== null) {
          setNewConnections(lastJsonMessage.data.ids);
        } else {
          setNewConnections([]);
        }
      // Add new value to newConnections state
      } else if (lastJsonMessage.event === "new_connection") {
        // If new connection exists in friendRequests, remove it
        const id = parseInt(lastJsonMessage.data.id);
        setFriendRequests((prev) => prev.filter((requestId) => requestId !== id));
        // Add to newConnections if reciever is the original request sender
        if (lastJsonMessage.data.is_sender === true) {
          // Make sure the id is a number type
          const id = parseInt(lastJsonMessage.data.id);
          setNewConnections((prev) => [...prev, id]);
        } else {
          sendJsonMessage({ event: "check_new_connection", data: { id: String(lastJsonMessage.data.id) } });
        }
      } else if (lastJsonMessage.event === "get_chat_list") {
        const chatList = lastJsonMessage.data;
        setChatList(chatList);
        if (!chatList) {
          setUnreadMessages(false);
          return;
        }
        // if chatlist has unread messages, set unreadMessages to true
        const hasUnreadMessages = chatList.some((room) => room.unReadMessage);
        setUnreadMessages(hasUnreadMessages);

      } else if (lastJsonMessage.event === "error") {
        console.log("WS ERROR!" + lastJsonMessage.data);
      }
    }
  }, [lastJsonMessage, sendJsonMessage]);
 
  // Show modal when there are new connections
  useEffect(() => {
    if (newConnections.length > 0) {
      const userId = newConnections[0];
      const controller = new AbortController();
      const signal = controller.signal;
      fetchUserData(userId, {signal}).then(({ userData, error }) => {
        if (!error) {
          setUserDataForModal(userData); // Update state with fetched user data
          setShowModal(true); // Show the modal
        } else {
          console.log(error.message);
        }
      }).catch((error) => {
        if (error.name === "AbortError") {
          console.log("Fetch aborted");
        }
      });
      return () => controller.abort();
    }

  }, [newConnections]);

  const closePopup = (userId) => {
    // Send json message to server to clear the new connection status
    sendJsonMessage({ event: "check_new_connection", data: { id: userId } });
    // Make sure userId is a number type
    userId = parseInt(userId);
    // Remove id from newConnections state
    setNewConnections((prev) => {
      const updated = prev.filter((id) => id !== userId);
      return updated;
    });
    setShowModal(false); // Hide the modal
  };

  const generateModalAlert = () => {
    if (showModal && userDataForModal) {
      return (
        <AlertModal open={showModal} onClose={() => closePopup(userDataForModal.id)}>
          <img src={userDataForModal.picture ? userDataForModal.picture : `${process.env.PUBLIC_URL}/images/defaultProfile.png`} alt="dog" />
          <p>{userDataForModal.dog_name} is your new connection!</p>
        </AlertModal>
      );
    }
    return null;
  };
  
  // Functions to handle socket connection
  const login = () => {
    setLoggedIn(true);
  };
  const logout = () => {
    setLoggedIn(false);
  }

  // Functions to clear notifications
  const clearFriendNotification = (idToRemove) => {
    idToRemove = Number(idToRemove);
    setFriendRequests((prevList) => prevList.filter((id) => id !== idToRemove));
    console.log("Friend request notification cleared for id: ", idToRemove)
  };

  return (
    <AuthContext.Provider value={{ 
      loggedIn, 
      login, 
      logout, 
      sendJsonMessage,
      lastJsonMessage, 
      friendRequests,
      unreadMessages,
      chatList,
      clearFriendNotification,
      }}>
      {generateModalAlert()}
      {children}
    </AuthContext.Provider>
  );
};