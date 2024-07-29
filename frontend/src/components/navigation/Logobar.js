import handleLogout from "../../tools/handleLogout";
import { useNavigate } from "react-router-dom";
import { useAuth } from '../../tools/AuthContext';

const Logobar = () => {
    const navigate = useNavigate();
    const { logout } = useAuth(); 


    // If path is login or register, show only logo
    if (window.location.pathname === "/login" || window.location.pathname === "/register") {
        return (
            <div className="logobar">
                <img className="logo" src={`${process.env.PUBLIC_URL}/images/logo.png`} alt="logo" />
            </div>
        );
    }

    return (
        <div className="logobar">
            <img className="logo" src={`${process.env.PUBLIC_URL}/images/logo.png`} alt="logo" />
            <img onClick={() => handleLogout(navigate, { logout })} className="button logoutLogo" src={`${process.env.PUBLIC_URL}/images/logout.png`} alt="logout" />
        </div>
    );
    }

export default Logobar;