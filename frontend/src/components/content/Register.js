import { useState, useEffect } from 'react';
import Cropper from 'react-easy-crop';
import getCroppedImg from '../../tools/getCroppedImg';

const Register = () => {
    const [form, setForm] = useState({
        email: '',
        password: '',
        confirm_password: '',
        add_picture: false,
        location_options: 'Live',
        dog_name: '',
        gender: 'male',
        neutered: false,
        size: '',
        energy_level: 'low',
        favorite_play_style: 'wrestling',
        age: '',
        preferred_distance: 0,
        preferred_gender: 'any',
        preferred_neutered: false,
        about_me: '',
    });
    const [imageSrc, setImageSrc] = useState(null);
    const [crop, setCrop] = useState({ x: 0, y: 0 });
    const [zoom, setZoom] = useState(1);
    const [error, setError] = useState(null);
    const [isPending, setIsPending] = useState(false);
    const [controller, setController] = useState(null); 

    // For debugging
    useEffect(() => {
        console.log(imageSrc, crop, zoom, form.add_picture);
    }, [imageSrc, crop, zoom, form.add_picture]);


    const handleChange = (name, value) => {
        setForm({
            ...form,
            [name]: value,
        });
    };

    const handleFileChange = async (e) => {
        if (e.target.files && e.target.files.length > 0) {
          const file = e.target.files[0];
          setImageSrc(URL.createObjectURL(file));
          handleChange('add_picture', true);
        }
    };

    const handleRemove = () => {
        setImageSrc(null);
        setCrop({ x: 0, y: 0 });
        setZoom(1);
        handleChange('add_picture', false);
        document.getElementById('file-input').value = '';
    };

    const handleClick = () => {
        document.getElementById('file-input').click();
    };

    useEffect(() => {
        // Cleanup function to abort the fetch if necessary
        return () => {
            if (controller) {
                controller.abort();
            }
        };
    }, [controller]);

    const handleSubmit = async (event) => {
        console.log(form);
        event.preventDefault(); 
        setIsPending(true);
        setError(null);
    
        const controller = new AbortController();
        setController(controller);
    
        try {
            const croppedImage = await getCroppedImg(imageSrc, crop, zoom);
            // First, send the form data
            console.log(form);
            let response = await fetch('http://localhost:3000/register', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(form),
                signal: controller.signal,
            });
    
            if (!response.ok) {
                const text = await response.text();
                throw new Error(text);
            }
    
            // After the first request completes, send the cropped image
            response = await fetch('http://localhost:3000/register', {
                method: 'POST',
                body: croppedImage, 
                signal: controller.signal,
            });
    
            if (!response.ok) {
                const text = await response.text();
                throw new Error(text);
            }
    
            setIsPending(false);
        } catch (err) {
            if (err.name !== 'AbortError') {
                setError(err.message);
                setIsPending(false);
            }
        }
    };

    return (
        <div className="oneColumnCard card">
            <h2>Welcome to Pawfect Match!</h2>
            <p>
                We need some info about you and your dog to match you 
                with the most suitable play mates. 
                This info can be modified later in the profile settings. 
                Mandatory fields are marked with an asterisk (*).
            </p>
            <form className="twoColumnCard" onSubmit={handleSubmit}>
                <div className="oneColumnCardLeft">
                <h4>Owner info</h4>
                <label htmlFor="email">E-mail: *</label><br />
                <input 
                    type="email" 
                    id="email" 
                    name="email" 
                    required
                    value={form.email}
                    onChange={(e) => handleChange(e.target.name, e.target.value)} /><br />
                <label htmlFor="password">Password: *</label><br />
                <input 
                    type="password" 
                    id="password" 
                    name="password"
                    maxLength={60}
                    value={form.password} 
                    required
                    onChange={(e) => handleChange(e.target.name, e.target.value)} /><br />
                <label htmlFor="confirmPassword">Repeat password: *</label><br />
                <input 
                    type="password" 
                    id="confirmPassword" 
                    name="confirm_password" 
                    maxLength={60}
                    value={form.confirm_password} 
                    required
                    onChange={(e) => handleChange(e.target.name, e.target.value)} /><br />
                <label htmlFor="locationOptions">My location: *</label><br />
                <select
                    name="location_options"
                    id="locationOptions"
                    value={form.location_options}
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                    >
                    <option value="Live">Use my live location</option>
                    <option value="Helsinki">Helisnki</option>
                    <option value="Tampere">Tampere</option>
                    <option value="Turku">Turku</option>
                    <option value="Jyväskylä">Jyväskylä</option>
                    <option value="Kuopio">Kuopio</option>
                </select>
                <h4>Pet info</h4>
                <label htmlFor="dogName">Name: *</label><br />
                <input 
                    type="text" 
                    id="dogName" 
                    name="dog_name" 
                    maxLength={30}
                    required
                    value={form.dog_name} 
                    onChange={(e) => handleChange(e.target.name, e.target.value)} /><br />
                <label htmlFor="age">Age: *</label><br />
                <input
                    type="text"
                    id="age"
                    name="age"
                    placeholder="age in years"
                    required
                    value={form.age}
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                /><br />
                <label htmlFor="gender">Gender: *</label>
                <select 
                    name="gender" 
                    id="gender"
                    value={form.gender} 
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                    >
                    <option value="male">male</option>
                    <option value="female">female</option>
                </select><br />
                <label htmlFor="size">Size: *</label><br />
                <input
                    type="text"
                    placeholder="size in kilograms"
                    id="size"
                    name="size"
                    required
                    value={form.size}
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                /><br />
                <label htmlFor="neutered">My dog is neutered/spayed: *</label>
                <input 
                    className="checkbox"
                    type="checkbox" 
                    id="neutered" 
                    name="neutered" 
                    value={form.neutered}
                    onChange={(e) => handleChange(e.target.name, e.target.checked)} /><br />             
                <label htmlFor="energyLevel">Energy level: *</label>
                <select 
                    name="energy_level" 
                    id="energyLevel"
                    value={form.energy_level} 
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                    >
                    <option value="low">low</option>
                    <option value="medium">medium</option>
                    <option value="high">high</option>
                </select><br />
                <label htmlFor="favoritePlayStyle">Favorite play style: *</label>
                <select 
                    name="favorite_play_style" 
                    id="favoritePlayStyle"
                    value={form.favorite_play_style} 
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                    >
                    <option value="wrestling">wrestling</option>
                    <option value="lonely wolf">lonely wolf</option>
                    <option value="cheerleading">cheerleading</option>
                    <option value="chasing">chasing</option>
                    <option value="tugging">tugging</option>
                    <option value="ripping">ripping</option>
                    <option value="soft touch">soft touch</option>
                    <option value="body slamming">body slamming</option>
                </select><br />
                <label htmlFor="aboutMe">About me and my owner:</label><br />
                <textarea
                    className="aboutMeBox"
                    id="aboutMe"
                    name="about_me"
                    maxLength={255}
                    value={form.about_me}
                    placeholder="Tell something about your dog and yourself to the other users..."
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                /><br />
                <output className="formOutput" htmlFor="aboutMe">{form.about_me.length}/255 characters</output><br />
                <h4>Upload a profile picture</h4>
                
                <input type="file" id="file-input" style={{ display: "none" }} accept="image/*" onChange={handleFileChange} />
                <div>
                    <button className="button"><img src={`${process.env.PUBLIC_URL}/images/upload.png`} alt="upload" onClick={handleClick} /></button>
                    {imageSrc && <button className="button" onClick={handleRemove}><img src={`${process.env.PUBLIC_URL}/images/remove.png`}></img></button>}
                </div>
                {!imageSrc && <p>No file uploaded!</p>}
                {imageSrc && <p>File uploaded! <br />Crop and zoom the picture here if needed:</p>}
                {imageSrc && <div style={{ position: "relative", width: 300, height: 300 }}>
                    <div>
                        <Cropper
                        image={imageSrc}
                        crop={crop}
                        zoom={zoom}
                        aspect={1}
                        onCropChange={setCrop}
                        onZoomChange={setZoom}
                        />
                    </div>
                </div>}
                <br />

                <h4>Preferences</h4>
                <p>Play mate should be...</p>
                <label htmlFor="prefGender">Gender: *</label>
                <select
                    name="preferred_gender"
                    id="prefGender"
                    value={form.preferred_gender}
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                >
                    <option value="any">any</option>
                    <option value="male">male</option>
                    <option value="female">female</option>
                </select><br />
                <label htmlFor="prefNeutered">Neutered/spayed: *</label>
                <input
                    className="checkbox"
                    type="checkbox"
                    id="prefNeutered"
                    name="preferred_neutered"
                    value={form.preferred_neutered}
                    onChange={(e) => handleChange(e.target.name, e.target.checked)}
                /><br />
                <label htmlFor="prefDistance">Located within: *</label>
                <input
                    type="range"
                    id="prefDistance"
                    name="preferred_distance"
                    value={form.preferred_distance}
                    onChange={(e) => handleChange(e.target.name, e.target.value)}
                    min={0}
                    max={30}
                />
                <output className="formOutput" htmlFor="prefDistance">{form.preferred_distance} km</output><br />
                </div>
                <div className="oneColumnCardLeft">
                    <button className="leftButton button" type="submit"><img src={`${process.env.PUBLIC_URL}/images/forward.png`}></img></button>
                </div>
                
                
                
            </form>
        </div>
        

    );
    }

export default Register;