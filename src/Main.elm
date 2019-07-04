port module Main exposing (main)

import Browser
import Browser.Dom exposing (Viewport, getViewport)
import Browser.Events exposing (onAnimationFrameDelta, onClick, onKeyDown, onKeyUp, onResize)
import Html exposing (Html, div, text)
import Html.Attributes exposing (height, style, width)
import Html.Events exposing (keyCode)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as DecodePipeline
import Json.Encode as Encode
import Math.Matrix4 as Mat4 exposing (Mat4)
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Task exposing (Task)
import WebGL exposing (Entity, Mesh, Shader)
import WebGL.Texture as Texture exposing (Error, Texture)



---- MODEL


type alias Model =
    { texture : Maybe Texture
    , keys : Keys
    , size : { width : Float, height : Float }
    , person : Person
    , pointerLockAcquired : Bool
    }


type alias Person =
    { position : Vec3
    , velocity : Vec3
    , horizontalAngle : Float
    , verticalAngle : Float
    }


type Msg
    = TextureLoaded (Result Error Texture)
    | KeyChange Bool Int
    | Animate Float
    | GetViewport Viewport
    | Resize Int Int
    | PointerLockRequested
    | PointerLockChanged Encode.Value
    | PointerMoved Encode.Value


type alias Keys =
    { left : Bool
    , right : Bool
    , up : Bool
    , down : Bool
    , space : Bool
    }


type alias Flags =
    { textures : Textures }


type alias Textures =
    { woodCratePath : String }



---- PROGRAM


main : Program Decode.Value Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , subscriptions = subscriptions
        , update = update
        }


init : Decode.Value -> ( Model, Cmd Msg )
init flagsValue =
    let
        flags =
            decodeFlags flagsValue
    in
    ( { texture = Nothing
      , person = Person (vec3 0 eyeLevel -10) (vec3 0 0 0) (degrees 90) 0
      , keys = Keys False False False False False
      , size = { width = 0, height = 0 }
      , pointerLockAcquired = False
      }
    , Cmd.batch
        [ Task.attempt TextureLoaded (Texture.load flags.textures.woodCratePath)
        , Task.perform GetViewport getViewport
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onAnimationFrameDelta Animate
        , onKeyDown (Decode.map (KeyChange True) keyCode)
        , onKeyUp (Decode.map (KeyChange False) keyCode)
        , onResize Resize
        , onClick (Decode.succeed PointerLockRequested)
        , pointerLockChanged PointerLockChanged
        , pointerMovement PointerMoved
        ]


eyeLevel : Float
eyeLevel =
    2



---- PORTS


port requestPointerLock : () -> Cmd msg


port pointerLockChanged : (Encode.Value -> msg) -> Sub msg


port pointerMovement : (Encode.Value -> msg) -> Sub msg



---- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
    case action of
        TextureLoaded textureResult ->
            ( { model | texture = Result.toMaybe textureResult }, Cmd.none )

        KeyChange on code ->
            ( { model | keys = keyFunc on code model.keys }, Cmd.none )

        GetViewport { viewport } ->
            ( { model
                | size =
                    { width = viewport.width
                    , height = viewport.height
                    }
              }
            , Cmd.none
            )

        Resize width height ->
            ( { model
                | size =
                    { width = toFloat width
                    , height = toFloat height
                    }
              }
            , Cmd.none
            )

        Animate dt ->
            ( { model
                | person =
                    if model.pointerLockAcquired then
                        model.person
                            |> move model.keys
                            |> gravity (dt / 500)
                            |> physics (dt / 500)

                    else
                        model.person
              }
            , Cmd.none
            )

        PointerLockRequested ->
            ( model
            , if model.pointerLockAcquired then
                Cmd.none

              else
                requestPointerLock ()
            )

        PointerLockChanged lockAcquired ->
            ( { model | pointerLockAcquired = defaultToFalse lockAcquired }, Cmd.none )

        PointerMoved movement ->
            ( { model | person = turn (defaultToNone movement) model.person }, Cmd.none )


turn : ( Int, Int ) -> Person -> Person
turn ( dx, dy ) person =
    let
        horizontal =
            person.horizontalAngle + toFloat dx / 500

        vertical =
            person.verticalAngle - toFloat dy / 500
    in
    { person
        | horizontalAngle = horizontal
        , verticalAngle = clamp (degrees -45) (degrees 45) vertical
    }


keyFunc : Bool -> Int -> Keys -> Keys
keyFunc on keyCode keys =
    case keyCode of
        32 ->
            { keys | space = on }

        37 ->
            { keys | left = on }

        39 ->
            { keys | right = on }

        38 ->
            { keys | up = on }

        40 ->
            { keys | down = on }

        _ ->
            keys


move : Keys -> Person -> Person
move { left, right, up, down, space } person =
    if Vec3.getY person.position <= eyeLevel then
        let
            forwardBackDirection =
                flatten (lookDirection person)

            sideToSideDirection =
                Mat4.transform (Mat4.makeRotate (degrees -90) Vec3.j) forwardBackDirection

            forwardBackVelocity =
                Vec3.scale (collapseKeys up down) forwardBackDirection

            sideToSideVelocity =
                Vec3.scale (collapseKeys right left) sideToSideDirection

            verticalVelocity =
                if space then
                    vec3 0 2 0

                else
                    vec3 0 (Vec3.getY person.velocity) 0

            totalVelocity =
                List.foldl
                    Vec3.add
                    (vec3 0 0 0)
                    [ forwardBackVelocity
                    , sideToSideVelocity
                    , verticalVelocity
                    ]
        in
        { person
            | velocity =
                if totalVelocity == vec3 0 0 0 then
                    totalVelocity

                else
                    Vec3.scale 2 (Vec3.normalize totalVelocity)
        }

    else
        person


flatten : Vec3 -> Vec3
flatten v =
    let
        r =
            Vec3.toRecord v
    in
    Vec3.normalize (vec3 r.x 0 r.z)


collapseKeys : Bool -> Bool -> Float
collapseKeys key1 key2 =
    if key1 == key2 then
        0

    else if key1 then
        1

    else
        -1


physics : Float -> Person -> Person
physics dt person =
    let
        position =
            Vec3.add person.position (Vec3.scale dt person.velocity)
    in
    { person
        | position =
            if Vec3.getY position < eyeLevel then
                Vec3.setY eyeLevel position

            else
                position
    }


gravity : Float -> Person -> Person
gravity dt person =
    if Vec3.getY person.position > eyeLevel then
        { person
            | velocity =
                Vec3.setY
                    (Vec3.getY person.velocity - 2 * dt)
                    person.velocity
        }

    else
        person



---- VIEW


view : Model -> Html Msg
view { size, person, texture } =
    div
        [ style "width" (String.fromFloat size.width ++ "px")
        , style "height" (String.fromFloat size.height ++ "px")
        , style "position" "absolute"
        , style "left" "0"
        , style "top" "0"
        ]
        [ WebGL.toHtmlWith
            [ WebGL.depth 1
            , WebGL.clearColor 0 0.75 1 0
            ]
            [ width (round size.width)
            , height (round size.height)
            , style "display" "block"
            ]
            (texture
                |> Maybe.map (scene size person)
                |> Maybe.withDefault []
            )
        , div
            [ style "position" "absolute"
            , style "font-family" "monospace"
            , style "color" "white"
            , style "text-align" "center"
            , style "left" "20px"
            , style "right" "20px"
            , style "top" "20px"
            ]
            [ text message ]
        ]


message : String
message =
    "Walk around with a first person perspective.\n"
        ++ "Arrows keys to move, space bar to jump."


scene : { width : Float, height : Float } -> Person -> Texture -> List Entity
scene { width, height } person texture =
    let
        perspective =
            Mat4.mul
                (Mat4.makePerspective 45 (width / height) 0.01 100)
                (Mat4.makeLookAt
                    person.position
                    (Vec3.add person.position (lookDirection person))
                    Vec3.j
                )
    in
    [ WebGL.entity
        vertexShader
        fragmentShader
        crate
        { texture = texture
        , perspective = perspective
        }
    ]


lookDirection : Person -> Vec3
lookDirection person =
    let
        h =
            person.horizontalAngle

        v =
            person.verticalAngle
    in
    vec3 (cos h) (sin v) (sin h)



---- MESH


type alias Vertex =
    { position : Vec3
    , coord : Vec2
    }


crate : Mesh Vertex
crate =
    [ ( 0, 0 ), ( 90, 0 ), ( 180, 0 ), ( 270, 0 ), ( 0, 90 ), ( 0, -90 ) ]
        |> List.concatMap rotatedSquare
        |> WebGL.triangles


rotatedSquare : ( Float, Float ) -> List ( Vertex, Vertex, Vertex )
rotatedSquare ( angleXZ, angleYZ ) =
    let
        transformMat =
            Mat4.mul
                (Mat4.makeRotate (degrees angleXZ) Vec3.j)
                (Mat4.makeRotate (degrees angleYZ) Vec3.i)

        transform vertex =
            { vertex
                | position =
                    Mat4.transform transformMat vertex.position
            }

        transformTriangle ( a, b, c ) =
            ( transform a, transform b, transform c )
    in
    List.map transformTriangle square


square : List ( Vertex, Vertex, Vertex )
square =
    let
        topLeft =
            Vertex (vec3 -1 1 1) (vec2 0 1)

        topRight =
            Vertex (vec3 1 1 1) (vec2 1 1)

        bottomLeft =
            Vertex (vec3 -1 -1 1) (vec2 0 0)

        bottomRight =
            Vertex (vec3 1 -1 1) (vec2 1 0)
    in
    [ ( topLeft, topRight, bottomLeft )
    , ( bottomLeft, topRight, bottomRight )
    ]



---- SHADERS


type alias Uniforms =
    { texture : Texture
    , perspective : Mat4
    }


vertexShader : Shader Vertex Uniforms { vcoord : Vec2 }
vertexShader =
    [glsl|

        attribute vec3 position;
        attribute vec2 coord;
        uniform mat4 perspective;
        varying vec2 vcoord;

        void main () {
          gl_Position = perspective * vec4(position, 1.0);
          vcoord = coord;
        }

    |]


fragmentShader : Shader {} Uniforms { vcoord : Vec2 }
fragmentShader =
    [glsl|

        precision mediump float;
        uniform sampler2D texture;
        varying vec2 vcoord;

        void main () {
          gl_FragColor = texture2D(texture, vcoord);
        }

    |]



---- DECODERS


decodeFlags : Decode.Value -> Flags
decodeFlags flags =
    let
        flagsDecodeResult =
            Decode.decodeValue flagsDecoder flags
    in
    Result.withDefault { textures = missingTextures } flagsDecodeResult


flagsDecoder : Decoder Flags
flagsDecoder =
    Decode.succeed Flags
        |> DecodePipeline.required "textures" texturesDecoder


texturesDecoder : Decoder Textures
texturesDecoder =
    Decode.succeed Textures
        |> DecodePipeline.required "woodCratePath" Decode.string


missingTextures : Textures
missingTextures =
    { woodCratePath = "Missing" }


defaultToFalse : Encode.Value -> Bool
defaultToFalse bool =
    Result.withDefault False (Decode.decodeValue Decode.bool bool)


defaultToNone : Encode.Value -> ( Int, Int )
defaultToNone tuple =
    Result.withDefault ( 0, 0 ) (decodeTuple tuple)


decodeTuple : Encode.Value -> Result Decode.Error ( Int, Int )
decodeTuple tuple =
    Decode.decodeValue
        (Decode.map2
            Tuple.pair
            (Decode.index 0 Decode.int)
            (Decode.index 1 Decode.int)
        )
        tuple
