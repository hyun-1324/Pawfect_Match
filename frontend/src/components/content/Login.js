import React, { useState } from 'react';
import { useEffect } from 'react';
import { Link } from 'react-router-dom';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(null);
    const [isPending, setIsPending] = useState(false);
    const [controller, setController] = useState(null); 

    useEffect(() => {
        // Cleanup function to abort the fetch if necessary
        return () => {
            if (controller) {
                controller.abort();
            }
        };
    }, [controller]);

    const handleSubmit = (event) => {
        event.preventDefault(); 
        setIsPending(true);
        setError(null);

        const controller = new AbortController();
        setController(controller);

        fetch('http://localhost:3000/login', {
            method: 'POST',
            headers: {'Content-Type': 'application/json',},
            body: JSON.stringify({ email, password }),
            signal: controller.signal,
        })
        .then(response => {
            if (!response.ok) {
                const errorText = response.text();
                throw new Error(errorText);
            }
            setIsPending(false);
            return response.json();
        }).catch(err => {
            if (err.name !== 'AbortError') {
                setError(err.message);
                setIsPending(false);
            }
        });
    };

    return (
        <div className="loginCard card">
            <div className="gridCard">
                <h2>Login</h2>
                {error && <div className="errorBox">Error:<br/>{error}</div>}
                <form onSubmit={handleSubmit}>
                    <label htmlFor="email">E-mail:</label><br />
                    <input 
                        type="email" 
                        id="email" 
                        name="email" 
                        required 
                        value={email} 
                        onChange={(e) => setEmail(e.target.value)} 
                    /><br />
                    <label htmlFor="password">Password:</label><br />
                    <input 
                        type="password" 
                        id="password" 
                        name="password" 
                        required 
                        maxLength={60} 
                        value={password} 
                        onChange={(e) => setPassword(e.target.value)} 
                    /><br />
                    {isPending && <button className="button" disabled><img src={`${process.env.PUBLIC_URL}/images/loading.png`} alt="Loading..."></img></button>}
                    {!isPending && <button className="button" type="submit"><img src={`${process.env.PUBLIC_URL}/images/forward.png`} alt="Log in"></img></button>}
                </form>
            </div>
            <div className="gridCard">
                <h3>Not a member yet?</h3>
                <Link to="/register" className="textButton button">Register here!</Link>
            </div>
        </div>
    );
}

export default Login;