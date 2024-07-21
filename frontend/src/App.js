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
import useWebSocket from "react-use-websocket";
import { AuthProvider } from './tools/AuthContext';


function App() {
  const [showConnectionNotification, setShowConnectionNotification] = useState(false);
  const [showChatNotification, setShowChatNotification] = useState(false);



  return (
    <AuthProvider>
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
    </AuthProvider>
  );
}

export default App;
