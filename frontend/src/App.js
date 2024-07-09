import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Logobar from './components/navigation/Logobar';
import Navbar from './components/navigation/Navbar';
import NotFound from './components/navigation/NotFound';
import Login from './components/content/Login';
import Register from './components/content/Register';
import Recommendations from './components/content/Recommendations';
import Profile from './components/content/Profile';
import Me from './components/content/Me';
import EditProfile from './components/content/EditProfile';
import EditPreferences from './components/content/EditPreferences';
import ChatList from './components/content/ChatList';
import Chat from './components/content/Chat';
import Connections from './components/content/Connections';

function App() {
  return (
    <Router>
      <div className="App">
        <Logobar />
        <Navbar />
        <div className="content"> 
          <Routes>
            <Route exact path="/">
              <Login />
            </Route>
            <Route path="/register">
              <Register />
            </Route>
            <Route path="/recommendations">
              <Recommendations />
            </Route>
            <Route path="/profile/:id">
              <Profile />
            </Route>
            <Route path="/me">
              <Me />
            </Route>
            <Route path="/edit/profile">
              <EditProfile />
            </Route>
            <Route path="/edit/preferences">
              <EditPreferences />
            </Route>
            <Route exact path="/chat">
              <ChatList />
            </Route>
            <Route path="/chat/:id">
              <Chat />
            </Route>
            <Route path="/connections">
              <Connections />
            </Route>
            <Route path="*">
              <NotFound/>
            </Route>
          </Routes>
        </div>
      </div>
    </Router>
  );
}

export default App;
