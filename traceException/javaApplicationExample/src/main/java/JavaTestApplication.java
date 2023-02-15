import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class JavaTestApplication {
    private static final Logger log= LoggerFactory.getLogger(JavaTestApplication.class);
    public static void main(String[] args) {
        try{
            myException();
        }catch (Exception e){
            handleException(e);
            //log.info(String.format("s= %s , a= %d: .", s, a), e);
        }
    }
    public static void myException() {
        try {
            Thread.sleep(2 * 60 * 1000); // wait for 5 minutes
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        throw new RuntimeException("An error occurred");
    }
    public static void handleException(Throwable t) {
        log.info("an exception occured in class= {} , from  {}:\n {}.", TestLog4j.class.getSimpleName(),new Throwable().getStackTrace()[1].getMethodName() , t);

    }
}