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


function App() {
  const [showConnectionNotification, setShowConnectionNotification] = useState(false);
  const [showChatNotification, setShowChatNotification] = useState(false);
  
  /*function connect() {
    const ws = new WebSocket('ws://localhost:8080/ws);

    ws.onclose = function(e) {
        console.log('Socket is closed. Reconnect will be attempted in 1 second.', e.reason);
        setTimeout(function() {
            connect();
        }, 1000);
    };

    ws.onerror = function(err) {
        console.error('Socket encountered error: ', err.message, 'Closing socket');
        ws.close();
    };
  }

  connect(); */

  return (

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

  );
}

export default App;
