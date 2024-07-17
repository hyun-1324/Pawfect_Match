
const handleLogout = async (navigate) => {
    
    try {
        const response = await fetch('http://localhost:3000/handle_logout', {
            method: 'GET',
            headers: {'Content-Type': 'application/json'}
        })
        if (!response.ok) {
            throw new Error("Logout failed!");
        }
        navigate('/login');
    }
    catch (err) {
        console.log(err);
    }
}

export default handleLogout;