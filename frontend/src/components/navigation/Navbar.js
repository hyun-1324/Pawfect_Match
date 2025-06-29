import { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";
import handleLogout from "../../tools/handleLogout";
import { useAuth } from '../../tools/AuthContext';

const Navbar = () => {
    const navigate = useNavigate();
    const { logout, friendRequests, unreadMessages, sendJsonMessage } = useAuth(); 
    const [newFriendRequests, setNewFriendRequests] = useState(false);
    const [newMessages, setNewMessages] = useState(false);

    useEffect(() => {
        if (friendRequests?.length > 0) {
            setNewFriendRequests(true);
        } else {
            setNewFriendRequests(false);
        }
    }, [friendRequests]);
    
    useEffect(() => {
        if (unreadMessages) {
            setNewMessages(true);
        } else {
            setNewMessages(false);
        }
    }, [unreadMessages]);
        

    if (window.location.pathname === "/login" || window.location.pathname === "/register") {
        return (
            <nav className="navbar" style={{backgroundColor:"#C4DDF2", display:"flex"}}>
                <div className="welcomeText">
                    <p>
                        Welome to Pawfect Match!<br/><br/>
                        With this app you can find the most suitable play mates for your dog.<br/><br/>
                        Log in or register to get started!
                    </p>
                    <img className="loginImage" src={`${process.env.PUBLIC_URL}/images/loginDog.png`} alt="dog" />
                </div>
            </nav>

        );
    }
    
    return (
        <nav className="navbar"> 
        
            <div className="navLink">
                <Link to="/"><img className="button navButton" src={`${process.env.PUBLIC_URL}/images/recommendations.png`} alt="Recommendations"></img><span className="navText">Recommendations</span></Link>
            </div>
            <div className="navLink">
                <Link to="/myconnections">
                    <div className="notificationImageContainer">
                        <img className="button navButton" src={`${process.env.PUBLIC_URL}/images/connections.png`} alt="Connections"></img>
                        {newFriendRequests && <div id="connectionNotification" className="notificationMark"></div>}
                    </div>
                    <span className="navText">Connections</span>
                </Link>
            </div>
            <div className="navLink">
                <Link to="/chat">
                <div className="notificationImageContainer">
                    <img className="button navButton" src={`${process.env.PUBLIC_URL}/images/chat.png`} alt="Messages"></img>
                    {newMessages&& <div id="chatNotification" className="notificationMark"></div>}
                </div>
                <span className="navText">Messages</span>
                </Link>
            </div>
            <div className="navLink">
                <Link to="/myprofile"><img className="button navButton" src={`${process.env.PUBLIC_URL}/images/profile.png`} alt="Profile"></img><span className="navText">Profile</span></Link>
            </div>
            <div className="navLinkLogout">
                <img onClick={() => handleLogout(navigate, logout, sendJsonMessage)} className="button navButton logoutNav" src={`${process.env.PUBLIC_URL}/images/logout.png`} alt="logout" />
                <span className= "navText">Logout</span>
            </div>
        
        </nav>
    );
};


export default Navbar;
