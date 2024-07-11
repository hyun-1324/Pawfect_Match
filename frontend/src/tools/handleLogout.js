const handleLogout = () => {
    fetch('http://localhost:3000/logout', {
        method: 'GET',
        headers: {'Content-Type': 'application/json'}
    }) 
}

export default handleLogout;