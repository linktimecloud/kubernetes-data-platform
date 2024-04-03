# HDFS Developer Guide

This guide will introduce how to perform HDFS operations using the Java API interface.

## HDFS Initialization

Before using the APIs provided by HDFS, you need to initialize HDFS first. During the initialization of HDFS, the configuration files of HDFS will be loaded. The main configuration files used by HDFS are `core-site.xml` and `hdfs-site.xml`, which can be obtained from the configmap `hdfs-config`.

The initialization code example is as follows:

```java
 private void init() throws IOException {
   conf = new Configuration();
   // conf path for core-site.xml and hdfs-site.xml
   conf.addResource(new Path(PATH_TO_HDFS_SITE_XML));
   conf.addResource(new Path(PATH_TO_CORE_SITE_XML));
   fSystem = FileSystem.get(conf);
 }
```

After initializing the HDFS file system, you can call various APIs provided by HDFS for development.

## Creating a Directory

To create a directory in the HDFS file system, you need to use the exists method of the FileSystem instance to determine whether the directory already exists:

- If it exists, simply return.
- If it does not exist, call the mkdirs method of the FileSystem instance to create the directory.

The code example for creating a directory is as follows:

```java
/**
 * create directory path
 *
 * @param dirPath
 * @return
 * @throws java.io.IOException
 */
private boolean createPath(final Path dirPath) throws IOException {
    if (!fSystem.exists(dirPath)) {
        fSystem.mkdirs(dirPath);
    }
    return true;
}
```

## Writing a File

To write a file, call the create method of the FileSystem instance to obtain the output stream for writing the file. After obtaining the output stream, you can directly write to it, putting the content into the specified file in HDFS. After writing the file, you need to call the close method to close the output stream.

The code example for writing a file is as follows:

```java
/**
 * Create a file, write to a file
 *
 * @throws java.io.IOException
 */
private void createAndWrite() throws IOException {
   final String content = "Hello HDFS!";
   FSDataOutputStream out = null;
   try {
       out = fSystem.create(new Path(DEST_PATH + File.separator + FILE_NAME));
       out.write(content.getBytes());
       out.hsync();
       LOG.info("success to write.");
   } finally {
    // make sure the stream is closed finally.
       out.close();
  }
}
```

## Appending to a File

For a file that already exists in HDFS, you can append specified content, incrementally adding it after the existing content of the file. Call the append method of the FileSystem instance to obtain the output stream for appending. Then use this output stream to add the content to be appended after the specified file in HDFS. After appending the specified content, you need to call the close method to close the output stream.

> **Note**：Ensure that the file to be appended already exists and is not being written to; otherwise, the append operation will fail and throw an exception.

The code example for appending to a file is as follows:

```java
/**
 * Append to a file
 *
 * @throws java.io.IOException
 */
private void appendContents() throws IOException {
    final String content = "Hello Hello";
    FSDataOutputStream out = null;
    try {
        out = fSystem.append(new Path(DEST_PATH + File.separator + FILE_NAME));
        out.write(content.getBytes());
        out.hsync();
        LOG.info("success to append.");
    } finally {
        // make sure the stream is closed finally.
        out.close();
    }
}
```

## Reading a File

Reading a file involves obtaining the content of a specified file on HDFS. Call the open method of the FileSystem instance to get the input stream for reading the file. Then use this input stream to read the content of the specified file in HDFS. After reading the file, you need to call the close method to close the input stream.

The code example for reading a file is as follows:

```java
private void read() throws IOException {
    String strPath = DEST_PATH + File.separator + FILE_NAME;
    Path path = new Path(strPath);
    FSDataInputStream in = null;
    BufferedReader reader = null;
    StringBuffer strBuffer = new StringBuffer();
    try {
        in = fSystem.open(path);
        reader = new BufferedReader(new InputStreamReader(in));
        String sTempOneLine;
        // write file
        while ((sTempOneLine = reader.readLine()) != null) {
            strBuffer.append(sTempOneLine);
        }
        LOG.info("result is : " + strBuffer.toString());
        LOG.info("success to read.");
    } finally {
        // make sure the streams are closed finally.
        IOUtils.closeStream(reader);
        IOUtils.closeStream(in);
    }
}
```

## Deleting a Directory

Delete a specified directory on HDFS by calling the delete method. The second parameter of the delete method represents whether to recursively delete all subdirectories under the directory. If the parameter is false, and there are still files or subdirectories under the directory, the delete directory operation will fail.

> **Note**：The directory to be deleted will be deleted directly and cannot be recovered, so please use the delete directory operation with caution.

The code example for deleting a directory is as follows:

```java
private boolean deletePath(final Path dirPath) throws IOException {
    if (!fSystem.exists(dirPath)) {
        return false;
    }
    // fSystem.delete(dirPath, true);
    return fSystem.delete(dirPath, true);
}
```

## Deleting a File

Delete a specified file on HDFS by calling the delete method.

> **Note**：The file to be deleted will be deleted directly and cannot be recovered, so please use the delete file operation with caution.

The code example for deleting a file is as follows:

```java
private void deleteFile() throws IOException {
    Path beDeletedPath = new Path(DEST_PATH + File.separator + FILE_NAME);
    if (fSystem.delete(beDeletedPath, true)) {
        LOG.info("success to delete the file " + DEST_PATH + File.separator + FILE_NAME);
    } else {
        LOG.warn("failed to delete the file " + DEST_PATH + File.separator + FILE_NAME);
    }
}
```

## Moving or Renaming a File

For HDFS, file renaming and moving are the same operation. Call the rename method of FileSystem to rename files in the HDFS file system.

> **Note**：The original file for the rename method must exist, and the target file must not exist; otherwise, the rename operation will fail.

The code example for moving or renaming a file is as follows:

```java
private void renameFile() throws IOException {
    Path srcFilePath = new Path(SRC_PATH + File.separator + SRC_FILE_NAME);
    Path destFilePath = new Path(DEST_PATH + File.separator + DEST_FILE_NAME);
        fs.rename(new Path(srcFilePath), new Path(destFilePath));
}
```

## Moving or Renaming a Directory

For HDFS, directory renaming and moving are the same operation. Call the rename method of FileSystem to rename directories in the HDFS file system.

> **Note**：The original directory for the rename method must exist, and the target directory must not exist; otherwise, the rename operation will fail.


The code example for moving or renaming a directory is as follows:

```java
private void renameDir() throws IOException {
    Path srcDirPath = new Path(SRC_PATH + File.separator + SRC_DIR_NAME);
    Path destDirPath = new Path(DEST_PATH + File.separator + DEST_DIR_NAME);
        fs.rename(new Path(srcDirPath), new Path(destDirPath));
}
```
