import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../tools/AuthContext';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(null);
    const [isPending, setIsPending] = useState(false);
    const [isLoading, setIsLoading] = useState(true);
    const [controller, setController] = useState(null); 
    
    const { login, logout } = useAuth(); 
    
    const navigate = useNavigate();

    // Cleanup function (abort controller) for the fetch request
    useEffect(() => {
        return () => {
            if (controller) {
                controller.abort();
            }
        };
    }, [controller]);

    // Redirect to recommendations page if user is already logged in
    useEffect(() => {
        if (logout && navigate) {
            setIsLoading(true);
            const checkLoginStatus = async () => {
                const controller = new AbortController();
                setController(controller);
                try {
                    const response = await fetch('http://localhost:3000/login_status',{ signal: controller.signal });
                    if (!response.ok) {
                        if (response.status === 400) {
                            navigate('/'); 
                        } else if (response.status === 500) {
                            setError('Can not reach server');
                        }
                    } else {
                        logout();
                    }
                } catch (error) {
                    if (error.name === 'AbortError') {
                       
                    } else {
                        setError(error.message);
                    }
                } finally {
                    setIsLoading(false);
                    setController(null);
                }
            };
            checkLoginStatus();
        }
    }, [logout, navigate]); 

    const handleSubmit = async (event) => {
        
        event.preventDefault(); 
        setIsPending(true);
        setError(null);
    
        const controller = new AbortController();
        setController(controller);
    
        try {
            const response = await fetch('http://localhost:3000/handle_login', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({ email, password }),
                signal: controller.signal,
            });
    
            if (!response.ok) {
                // Handle HTTP errors
                const errorResponse = await response.json();
                const errorMessage = errorResponse.Message;
                const error = new Error(errorMessage);
                error.response = errorResponse; 
                throw error;
            }
            // Set the WebSocket connection
            login();

            setIsPending(false);
            navigate('/');
        } catch (err) {
            setIsPending(false);
            if (err.name === 'AbortError') {
                // The request was aborted
            } else if (err.response && err.response.Message) {
                // This is an HTTP error that was thrown manually in the try block
                setError(err.response.Message);
            } else {
                // This is likely a network error
                setError('Network error, please try again.');
            }
        }
    };

    return (
        <>
            {!isLoading && <div className="twoColumnCard card centered">
                <div className="oneColumnCardCentered">
                    <h2>Login</h2>
                    {error && <div className="errorBox">Error:<br/>{error}</div>}
                    <form onSubmit={ (event) => handleSubmit(event)}>
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
                <div className="oneColumnCardCentered">
                    <h3>Not a member yet?</h3>
                    <Link to="/register" className="textButton button">Register here!</Link>
                </div>
            </div>}
        </>
            
    );
}

export default Login;