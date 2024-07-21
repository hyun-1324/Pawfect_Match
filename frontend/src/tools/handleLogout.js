

const handleLogout = async (navigate, { logout }) => {
    
    try {
        
        // Close the WebSocket connection 
        logout();
     
        const response = await fetch('http://localhost:3000/handle_logout', {
            method: 'GET',
            headers: {'Content-Type': 'application/json'}
        });
        if (!response.ok) {
            throw new Error("Logout failed!");
        }
         // Set isLoggedIn to false
        
        navigate('/login');
    }
    catch (err) {
        console.log(err);
    }
}

export default handleLogout;