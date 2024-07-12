import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import Logobar from "./components/navigation/Logobar";
import Navbar from "./components/navigation/Navbar";
import NotFound from "./components/navigation/NotFound";
import Login from "./components/content/Login";
import Register from "./components/content/Register";
import Recommendations from "./components/content/Recommendations";
import Profile from "./components/content/Profile";
import Me from "./components/content/Me";
import EditProfile from "./components/content/EditProfile";
import EditPreferences from "./components/content/EditPreferences";
import ChatList from "./components/content/ChatList";
import Chat from "./components/content/Chat";
import Connections from "./components/content/Connections";

function App() {
  return (
    <Router>
      <div className="App">
        <Logobar />
        <Navbar />
        <div className="content"> 
          <Routes>
          <Route exact path="/" element={<Recommendations />} />
            <Route path="/register" element={<Register />} />
            <Route path="/login" element={<Login />} />
            <Route path="/profile/:id" element={<Profile />} />
            <Route path="/me" element={<Me />} />
            <Route path="/edit/profile" element={<EditProfile />} />
            <Route path="/edit/preferences" element={<EditPreferences />} />
            <Route exact path="/chat" element={<ChatList />} />
            <Route path="/chat/:id" element={<Chat />} />
            <Route path="/connections" element={<Connections />} />
            <Route path="*" element={<NotFound/>}/>
          </Routes>
        </div>
      </div>
    </Router>
  );
}

export default App;
