const Login = () => {
    return (
        
        <div className="loginCard card">
            <h2>Login</h2>
            <form>
                <label htmlFor="email">E-mail:</label>
                <input type="email" id="email" name="email" required />
                <label htmlFor="password">Password:</label>
                <input type="password" id="password" name="password" required maxLength={50} />
                <button type="submit">Login</button>
            </form>
        </div>
    
    );
}

export default Login;