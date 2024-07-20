import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import { useEffect, useState } from "react";
import Logobar from "./components/navigation/Logobar";
import Navbar from "./components/navigation/Navbar";
import NotFound from "./components/navigation/NotFound";
import Login from "./components/content/Login";
import Register from "./components/content/Register";
import Recommendations from "./components/content/Recommendations";
import Profile from "./components/content/Profile";
import MyProfile from "./components/content/MyProfile";
import EditProfile from "./components/content/EditProfile";
import ChatList from "./components/content/ChatList";
import Chat from "./components/content/Chat";
import Connections from "./components/content/Connections";
import { socket } from './socket';
import { SocketContext } from './socketContext';

function App() {
  const [showConnectionNotification, setShowConnectionNotification] = useState(false);
  const [showChatNotification, setShowChatNotification] = useState(false);
  
  /*useEffect(() => {
      // Define event handlers
      const handleFriendRequests = (ids) => {
          setShowConnectionNotification(ids.length > 0);
      };
  
      const handleUnreadMessages = (isTrue) => {
          setShowChatNotification(isTrue);
      };
  
      // Subscribe to socket events
      socket.on("friendRequests", handleFriendRequests);
      socket.on("check_unread_messages", handleUnreadMessages);
  
      // Cleanup function to unsubscribe from events
      return () => {
          socket.off("friendRequests", handleFriendRequests);
          socket.off("check_unread_messages", handleUnreadMessages);
      };
  }, [socket]); // Dependencies array ensures effect runs only when `socket` changes*/



  return (
    <SocketContext.Provider value={socket}>
      <Router>
        <div className="App">
          <Logobar />
          <Navbar showChatNotification={showChatNotification} showConnectionNotification={showConnectionNotification}/>
          <div className="content">
            <Routes>
              <Route exact path="/" element={<Recommendations />} />
              <Route path="/register" element={<Register />} />
              <Route path="/login" element={<Login />} />
              <Route path="/profile/:id" element={<Profile />} />
              <Route path="/myprofile" element={<MyProfile />} />
              <Route path="/edit/profile" element={<EditProfile />} />
              <Route exact path="/chat" element={<ChatList />} />
              <Route path="/chat/:id" element={<Chat />} />
              <Route path="/myconnections" element={<Connections />} />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </div>
        </div>
      </Router>
    </SocketContext.Provider>
  );
}

export default App;
